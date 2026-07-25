import SwiftUI
import UIKit

/// アプリ共通の配色。ART_PROMPTS.md の STYLE SPEC と揃えている。
///
/// **背景色を固定するなら、文字色も必ずセットで面倒を見ること。**
/// 背景だけ固定して文字を `.primary` / `.secondary` のまま放置すると、
/// ダークモードで「明るい背景に白文字」になり読めなくなる（実際に起きた。§15-9）。
/// ここでは背景側をモード追従にすることで、`.primary` / `.secondary` を
/// そのまま正しく機能させている。
enum Theme {
    static let background = adaptive(light: 0xE8E4DC, dark: 0x1B1922)
    static let card       = adaptive(light: 0xF6F4EF, dark: 0x26232F)

    /// アイコンと強調テキスト。背景の明暗が反転するので明度を入れ替える。
    static let accent     = adaptive(light: 0x5F5B76, dark: 0xADA5C9)

    /// 主ボタンの塗り。上に白文字を載せるため両モードとも十分に暗い色で固定する。
    static let accentFill = adaptive(light: 0x6B6782, dark: 0x6B6782)

    /// 活力（AP）。歩数に由来する資源なので、他と区別できる暖色にする。
    static let vigor      = adaptive(light: 0x9A6F4A, dark: 0xD6A97C)

    /// 危険・敗北。
    static let danger     = adaptive(light: 0x9B4A4A, dark: 0xD68A8A)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(rgb: Int) {
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue:  CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - 共通部品

/// 数値を1つ見せるための枠。ホームで多用する。
struct StatTile: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// HP や活気ゲージ。
struct MeterBar: View {
    var value: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 8)
    }
}
