import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// ART_PROMPTS.md §4 の後処理を自動化するツール。
//
// 「生成のばらつきはここで吸収する。最も費用対効果が高い工程なので省略しない」と
// 書いてあるとおり、統一感はこの工程で決まる。手作業でやると必ずブレるので機械化する。
//
//   swiftc -O -o artpipeline tools/artpipeline/main.swift
//   ./artpipeline <入力.png> <出力.png>
//
// 処理:
//   1. 背景を透過にする（四辺から塗りつぶし範囲を広げる方式）
//   2. 縁のにじみを削る
//   3. 中身の外接矩形で切り出し、1024×1024 の中央へ既定の比率で再配置
//   4. ポスタリゼーション（減色）

// MARK: - 設定

enum Config {
    static let canvasSize = 1024

    /// 生成時の背景色 #E8E4DC。焼き込みで出てきた場合にこれを除去する。
    static let backgroundHint: (r: Double, g: Double, b: Double) = (0xE8, 0xE4, 0xDC)

    /// 背景とみなす色距離のしきい値（0〜441）。大きすぎると本体を削る。
    static let tolerance = 62.0

    /// 閉じた領域に残った背景を消すための、より厳しいしきい値。
    ///
    /// 外周から繋がっていない背景（触手の隙間、腕と胴の間）は最初の塗りつぶしでは届かない。
    /// かといって同じしきい値で全画素を消すと、**ネムケの白目のような明るい部位まで抜ける**。
    /// 背景 #E8E4DC と純白の距離は約50なので、その半分程度に絞って区別する。
    static let enclosedTolerance = 26.0

    /// 閉じた領域として消す最小面積。
    ///
    /// **ダラリの白目は背景色とほぼ同一で、色では区別できなかった。**
    /// しきい値を 12 まで絞っても目が抜ける。一方で目は小さく、腕と胴の隙間や
    /// 触手の間は大きいため、面積で分けている。実測して 4000 に決めた。
    ///
    /// これは**背景を焼き込んで生成された旧仕様の画像のための救済措置**。
    /// 新しいアートは STYLE SPEC どおり透過で生成されるので、この工程は素通りする。
    static let minimumEnclosedArea = 4000

    /// キャンバス高さに対する本体の高さの比率。ART_PROMPTS.md は 70%（ボスは 85%）。
    static let contentHeightRatio = 0.70

    /// ポスタリゼーションの階調数。8〜12色相当。
    static let posterizeLevels = 10

    /// 色の正規化の目標値。
    ///
    /// **明度と彩度はプロンプトで揃えようとしないこと。** 生成は毎回すべての属性を
    /// 引き直すため、色を指定し直すと造形が崩れる（実際にダラリで3回起きた）。
    /// シルエットは生成でしか作れないが、色は機械的に揃えられる。ここで吸収する。
    static let targetLuminance = 107.0
    static let targetSaturation = 0.23

    /// 背景の目標値。キャラクターより暗く、彩度も低く沈ませる。
    /// 立ち絵と同じ明るさだと、上に乗せたときに輪郭が埋もれる。
    static let backgroundTargetLuminance = 78.0
    static let backgroundTargetSaturation = 0.16

    /// 彩度が目標に届かない素材へ加算する色差の向き（灰紫）と最大量。
    /// 掛け算ではなく加算にすることで、色ムラを増幅せずに色味を寄せられる。
    static let tintDirection: (r: Double, g: Double, b: Double) = (6, -8, 14)
    static let tintStrength = 3.0

    /// 減色の前に色差を平滑化する半径。
    ///
    /// 生成物のテクスチャは、そのまま減色すると斑（まだら）として固まる。
    /// **輝度は触らず色差だけを平滑化する**ので、輪郭線の鋭さは保たれる。
    static let chromaBlurRadius = 3
}

// MARK: - 画像の読み書き

struct Bitmap {
    var width: Int
    var height: Int
    /// RGBA、1ピクセル4バイト。
    var pixels: [UInt8]

    subscript(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        get {
            let i = (y * width + x) * 4
            return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
        }
        set {
            let i = (y * width + x) * 4
            pixels[i] = newValue.r
            pixels[i + 1] = newValue.g
            pixels[i + 2] = newValue.b
            pixels[i + 3] = newValue.a
        }
    }

    static func load(_ path: String) -> Bitmap? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Bitmap(width: width, height: height, pixels: pixels)
    }

    func write(to path: String) -> Bool {
        var data = pixels
        guard let ctx = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = ctx.makeImage() else { return false }

        let url = URL(fileURLWithPath: path) as CFURL
        guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }
}

// MARK: - 1. 背景の除去

/// 四辺から連結している「背景色に近い領域」だけを透過にする。
///
/// 単純に「背景色に近い画素を全部消す」とやると、**本体の内側にある明るい部分まで穴が開く**。
/// 外周から繋がっている領域に限定することでそれを防ぐ。
func removeBackground(_ bitmap: inout Bitmap) -> Int {
    let w = bitmap.width, h = bitmap.height

    // 既に透過で生成されている場合は、除去処理を丸ごと飛ばす。
    //
    // **これを飛ばさないと明るい部位に穴が開く。** 透過画像では四隅から背景色を
    // 推定できず既定値 #E8E4DC が使われるため、1b の閉じた領域の判定が
    // 「背景色に近い明るい部分」＝白目などを誤って消してしまう。
    // 新しいアートは STYLE SPEC どおり透過で来るので、通常はこちらの経路を通る。
    var transparentBorder = 0
    var borderCount = 0
    for x in 0..<w {
        for y in [0, h - 1] {
            borderCount += 1
            if bitmap[x, y].a == 0 { transparentBorder += 1 }
        }
    }
    for y in 0..<h {
        for x in [0, w - 1] {
            borderCount += 1
            if bitmap[x, y].a == 0 { transparentBorder += 1 }
        }
    }
    if Double(transparentBorder) / Double(borderCount) > 0.9 {
        return 0
    }

    // 四隅の色から実際の背景色を推定する。生成物は指定色から微妙にずれるため、
    // 固定値ではなく現物に合わせる。
    var samples: [(Double, Double, Double)] = []
    for (x, y) in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)] {
        let p = bitmap[x, y]
        if p.a > 0 { samples.append((Double(p.r), Double(p.g), Double(p.b))) }
    }
    let bg: (r: Double, g: Double, b: Double)
    if samples.isEmpty {
        bg = Config.backgroundHint
    } else {
        bg = (
            samples.map(\.0).reduce(0, +) / Double(samples.count),
            samples.map(\.1).reduce(0, +) / Double(samples.count),
            samples.map(\.2).reduce(0, +) / Double(samples.count)
        )
    }

    func distance(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Double {
        let dr = Double(p.r) - bg.r, dg = Double(p.g) - bg.g, db = Double(p.b) - bg.b
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    var visited = [Bool](repeating: false, count: w * h)
    var queue: [Int] = []

    for x in 0..<w {
        queue.append(x)                    // 上辺
        queue.append((h - 1) * w + x)      // 下辺
    }
    for y in 0..<h {
        queue.append(y * w)                // 左辺
        queue.append(y * w + w - 1)        // 右辺
    }

    var removed = 0
    var head = 0
    while head < queue.count {
        let index = queue[head]; head += 1
        if visited[index] { continue }
        visited[index] = true

        let x = index % w, y = index / w
        guard distance(bitmap[x, y]) <= Config.tolerance else { continue }

        bitmap[x, y] = (0, 0, 0, 0)
        removed += 1

        if x > 0 { queue.append(index - 1) }
        if x < w - 1 { queue.append(index + 1) }
        if y > 0 { queue.append(index - w) }
        if y < h - 1 { queue.append(index + w) }
    }

    // 1b. 閉じた領域に残った背景を消す。
    //
    // 外周から繋がっていない背景（触手の隙間、腕と胴の間）はここまでで残っている。
    // 連結成分ごとに判定し、背景色に十分近く、かつある程度の面積があるものだけを消す。
    // 全画素を一律に消すと明るい部位まで抜けるため、連結性と面積で守る。
    var checked = [Bool](repeating: false, count: w * h)
    for startY in 0..<h {
        for startX in 0..<w {
            let start = startY * w + startX
            if checked[start] || bitmap[startX, startY].a == 0 { continue }
            guard distance(bitmap[startX, startY]) <= Config.enclosedTolerance else {
                checked[start] = true
                continue
            }

            var component: [Int] = []
            var stack = [start]
            checked[start] = true
            while let index = stack.popLast() {
                component.append(index)
                let x = index % w, y = index / w
                for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                    let next = ny * w + nx
                    guard !checked[next], bitmap[nx, ny].a > 0,
                          distance(bitmap[nx, ny]) <= Config.enclosedTolerance else { continue }
                    checked[next] = true
                    stack.append(next)
                }
            }

            guard component.count >= Config.minimumEnclosedArea else { continue }
            for index in component {
                bitmap[index % w, index / w] = (0, 0, 0, 0)
                removed += 1
            }
        }
    }

    // 2. 縁のにじみを削る。
    // 透過画素に隣接する画素は背景色が混ざっているため、そのままだと白い縁が残る。
    var softened = bitmap
    for y in 0..<h {
        for x in 0..<w where bitmap[x, y].a > 0 {
            var touchesTransparent = false
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                if bitmap[nx, ny].a == 0 { touchesTransparent = true; break }
            }
            guard touchesTransparent else { continue }
            let ratio = min(1.0, distance(bitmap[x, y]) / Config.tolerance)
            var p = bitmap[x, y]
            p.a = UInt8(Double(p.a) * ratio)
            softened[x, y] = p
        }
    }
    bitmap = softened
    return removed
}

// MARK: - 3. 切り出しと再配置

/// 不透明な範囲の外接矩形を求め、規定の比率で 1024×1024 の中央に置き直す。
///
/// **生成物はキャンバス内での大きさも位置もばらつく。** ここで揃えないと、
/// 図鑑に並べた時に1体だけ大きい・寄っている、という形で統一感が壊れる。
func normalize(_ bitmap: Bitmap) -> Bitmap? {
    var minX = bitmap.width, minY = bitmap.height, maxX = -1, maxY = -1
    for y in 0..<bitmap.height {
        for x in 0..<bitmap.width where bitmap[x, y].a > 8 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { return nil }

    let cropWidth = maxX - minX + 1
    let cropHeight = maxY - minY + 1
    let side = Config.canvasSize
    let targetHeight = Double(side) * Config.contentHeightRatio
    let scale = targetHeight / Double(cropHeight)
    let drawWidth = Double(cropWidth) * scale

    // 横に広い個体（ゴロネ）は幅で頭打ちにする。はみ出させない。
    let maxWidth = Double(side) * 0.86
    let finalScale = drawWidth > maxWidth ? maxWidth / Double(cropWidth) : scale

    var output = [UInt8](repeating: 0, count: side * side * 4)
    guard let ctx = CGContext(
        data: &output, width: side, height: side,
        bitsPerComponent: 8, bytesPerRow: side * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high

    var sourcePixels = bitmap.pixels
    guard let sourceCtx = CGContext(
        data: &sourcePixels, width: bitmap.width, height: bitmap.height,
        bitsPerComponent: 8, bytesPerRow: bitmap.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let sourceImage = sourceCtx.makeImage(),
       let cropped = sourceImage.cropping(to: CGRect(
           x: minX, y: bitmap.height - maxY - 1, width: cropWidth, height: cropHeight))
    else { return nil }

    let w = Double(cropWidth) * finalScale
    let hgt = Double(cropHeight) * finalScale
    ctx.draw(cropped, in: CGRect(
        x: (Double(side) - w) / 2,
        y: (Double(side) - hgt) / 2,
        width: w, height: hgt
    ))

    return Bitmap(width: side, height: side, pixels: output)
}

// MARK: - 3b. 色の正規化

/// 不透明部の平均明度と平均彩度を目標値へ寄せる。
///
/// 全アセットに同じ目標を適用するので、並べたときに「1体だけ明るい」「1体だけ紫」が
/// 構造的に起きなくなる。色相は触らないため、個体ごとの色味の差は残る。
func normalizeColor(_ bitmap: inout Bitmap) -> (luminance: Double, saturation: Double) {
    var lumSum = 0.0, satSum = 0.0, count = 0
    for y in 0..<bitmap.height {
        for x in 0..<bitmap.width {
            let p = bitmap[x, y]
            guard p.a > 128 else { continue }
            let r = Double(p.r), g = Double(p.g), b = Double(p.b)
            lumSum += 0.2126 * r + 0.7152 * g + 0.0722 * b
            let mx = max(r, g, b), mn = min(r, g, b)
            satSum += mx > 0 ? (mx - mn) / mx : 0
            count += 1
        }
    }
    guard count > 0 else { return (0, 0) }

    let meanLum = lumSum / Double(count)
    let meanSat = satSum / Double(count)
    let targetLum = isBackground ? Config.backgroundTargetLuminance : Config.targetLuminance
    let targetSat = isBackground ? Config.backgroundTargetSaturation : Config.targetSaturation
    let lumScale = meanLum > 0 ? targetLum / meanLum : 1
    // **彩度は下げる方向にしか掛け算しない。**
    // 引き上げると、元がほぼ無彩色の絵では微妙な色ムラまで増幅され、
    // 紫のまだらが浮き出る（初期版ダラリで実際に起きた）。
    let satScale = min(1.0, meanSat > 0 ? targetSat / meanSat : 1)

    // 目標を下回る場合は、掛け算ではなく**色差を一律に足して**色味を寄せる。
    // 加算は局所的な差を増幅しないので、ノイズが浮き出ない。
    let deficit = max(0, targetSat - meanSat * satScale)
    let tint = min(1.0, deficit / targetSat)

    for y in 0..<bitmap.height {
        for x in 0..<bitmap.width {
            var p = bitmap[x, y]
            guard p.a > 0 else { continue }
            var r = Double(p.r), g = Double(p.g), b = Double(p.b)

            // 彩度: 各画素の最大値からの差を縮める。色相は保つ。
            let mx = max(r, g, b)
            r = mx - (mx - r) * satScale
            g = mx - (mx - g) * satScale
            b = mx - (mx - b) * satScale

            // 足りない分は、灰紫の色差を一律に加算して寄せる。
            if tint > 0 {
                let amount = Config.tintStrength * tint
                r += Config.tintDirection.r * amount
                g += Config.tintDirection.g * amount
                b += Config.tintDirection.b * amount
            }

            // 明度: 全体を一律に伸縮させる。
            r *= lumScale; g *= lumScale; b *= lumScale

            p.r = UInt8(max(0, min(255, r)))
            p.g = UInt8(max(0, min(255, g)))
            p.b = UInt8(max(0, min(255, b)))
            bitmap[x, y] = p
        }
    }
    return (meanLum, meanSat)
}

// MARK: - 3c. 色差の平滑化

/// 輝度を保ったまま色差だけをぼかす。
///
/// 生成物の微細なテクスチャは、減色すると斑になって固まる。色差だけを均せば
/// 斑が消え、輝度は触らないので輪郭線と陰影の境界は鋭いまま残る。
func smoothChroma(_ bitmap: inout Bitmap) {
    let radius = Config.chromaBlurRadius
    guard radius > 0 else { return }
    let w = bitmap.width, h = bitmap.height
    let source = bitmap

    for y in 0..<h {
        for x in 0..<w {
            let p = source[x, y]
            guard p.a > 0 else { continue }

            var sumCb = 0.0, sumCr = 0.0, count = 0.0
            for dy in -radius...radius {
                for dx in -radius...radius {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                    let q = source[nx, ny]
                    guard q.a > 0 else { continue }
                    let r = Double(q.r), g = Double(q.g), b = Double(q.b)
                    let yy = 0.299 * r + 0.587 * g + 0.114 * b
                    sumCb += b - yy
                    sumCr += r - yy
                    count += 1
                }
            }
            guard count > 0 else { continue }

            let r = Double(p.r), g = Double(p.g), b = Double(p.b)
            let luma = 0.299 * r + 0.587 * g + 0.114 * b
            let cb = sumCb / count, cr = sumCr / count
            // Cb/Cr から RGB へ戻す（G は輝度の定義から逆算）
            let nb = luma + cb
            let nr = luma + cr
            let ng = (luma - 0.299 * nr - 0.114 * nb) / 0.587

            var out = p
            out.r = UInt8(max(0, min(255, nr)))
            out.g = UInt8(max(0, min(255, ng)))
            out.b = UInt8(max(0, min(255, nb)))
            bitmap[x, y] = out
        }
    }
}

// MARK: - 4. ポスタリゼーション

/// 全アセットに同一設定で適用する。生成ごとの微妙な色の揺れを吸収する。
func posterize(_ bitmap: inout Bitmap) {
    let levels = Double(Config.posterizeLevels - 1)
    for y in 0..<bitmap.height {
        for x in 0..<bitmap.width {
            var p = bitmap[x, y]
            guard p.a > 0 else { continue }
            func quantize(_ v: UInt8) -> UInt8 {
                UInt8((( Double(v) / 255 * levels).rounded() / levels * 255).rounded())
            }
            p.r = quantize(p.r); p.g = quantize(p.g); p.b = quantize(p.b)
            bitmap[x, y] = p
        }
    }
}

// MARK: - 実行

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("使い方: artpipeline <入力.png> <出力.png> [--background]")
    exit(2)
}

/// 背景画像は扱いが違う。透過させず、切り出して中央へ寄せることもしない。
/// **キャラクターより暗く沈ませる**ことで、上に乗る立ち絵が埋もれないようにする。
let isBackground = arguments.contains("--background")

guard var bitmap = Bitmap.load(arguments[1]) else {
    print("読み込めません: \(arguments[1])")
    exit(1)
}

var removed = 0
var normalized: Bitmap
if isBackground {
    normalized = bitmap
} else {
    removed = removeBackground(&bitmap)
    guard let recentred = normalize(bitmap) else {
        print("本体が見つかりません（背景の除去が効きすぎている可能性）: \(arguments[1])")
        exit(1)
    }
    normalized = recentred
}
smoothChroma(&normalized)
let before = normalizeColor(&normalized)
posterize(&normalized)

guard normalized.write(to: arguments[2]) else {
    print("書き出せません: \(arguments[2])")
    exit(1)
}

let total = bitmap.width * bitmap.height
let percent = Double(removed) / Double(total) * 100
print(String(format: "%@ → %@  背景除去 %.1f%%  色補正 明度%.0f→%.0f 彩度%.2f→%.2f",
             (arguments[1] as NSString).lastPathComponent,
             (arguments[2] as NSString).lastPathComponent,
             percent, before.luminance,
             isBackground ? Config.backgroundTargetLuminance : Config.targetLuminance,
             before.saturation,
             isBackground ? Config.backgroundTargetSaturation : Config.targetSaturation))
