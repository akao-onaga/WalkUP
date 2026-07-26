import CoreGraphics
import Foundation
import ImageIO
// ART_PROMPTS.md §5 の「明度が揃っているか」「アクセント色の面積」を実測する
print(String(format: "%-14@ %8@ %8@ %8@ %8@", "個体" as NSString, "平均明度" as NSString,
             "占有率" as NSString, "彩度" as NSString, "暖色面積" as NSString))
var lums: [Double] = []
for path in CommandLine.arguments.dropFirst() {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
        bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

    var lumSum = 0.0, satSum = 0.0, opaque = 0, warm = 0
    for i in stride(from: 0, to: px.count, by: 4) {
        let a = Double(px[i+3]) / 255
        guard a > 0.5 else { continue }
        let r = Double(px[i]) / a, g = Double(px[i+1]) / a, b = Double(px[i+2]) / a
        opaque += 1
        lumSum += 0.2126 * r + 0.7152 * g + 0.0722 * b
        let mx = max(r, g, b), mn = min(r, g, b)
        satSum += mx > 0 ? (mx - mn) / mx : 0
        // 暖色（アクセント色）: 赤が青より明確に強い
        if r > b + 28 { warm += 1 }
    }
    guard opaque > 0 else { continue }
    let lum = lumSum / Double(opaque)
    lums.append(lum)
    let name = (path as NSString).deletingPathExtension as NSString
    print(String(format: "%-14@ %8.1f %7.1f%% %8.3f %7.1f%%",
                 name.lastPathComponent as NSString, lum,
                 Double(opaque) / Double(w * h) * 100,
                 satSum / Double(opaque),
                 Double(warm) / Double(opaque) * 100))
}
if lums.count > 1 {
    let mean = lums.reduce(0,+) / Double(lums.count)
    let sd = (lums.map { ($0-mean)*($0-mean) }.reduce(0,+) / Double(lums.count)).squareRoot()
    print(String(format: "\n明度の幅: %.1f 〜 %.1f （差 %.1f / 標準偏差 %.1f）",
                 lums.min()!, lums.max()!, lums.max()! - lums.min()!, sd))
}
