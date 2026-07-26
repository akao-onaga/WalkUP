import SwiftUI
import UIKit

/// アプリ共通の配色。ART_PROMPTS.md の STYLE SPEC と揃えている。
///
/// **OS のライト／ダークには追従しない（2026-07-27 確定）。**
/// 追従させると、同じ画面が端末の設定で二つの顔を持つ。作品としての色が決まらず、
/// どちらでも破綻しないことを毎回確かめる必要が出て、そのぶん詰めが甘くなる。
/// ここは紙の色（`background`）に固定し、**アートが前提としている背景**に揃えた。
/// ダルモンの立ち絵はこの色（#E8E4DC）の上で描かれている（ART_PROMPTS.md §2）。
///
/// **色を固定した以上、文字色も自前で持つ。** `.primary` / `.secondary` は
/// OS のモードで反転するので、ここでは使わない（`text` / `textSoft` を使う）。
/// 背景だけ固定して文字を放置し、ダークモードで読めなくした事故を2度起こしている。
enum Theme {
    static let background = fixed(0xE8E4DC)
    static let card       = fixed(0xF6F4EF)

    /// アイコンと強調テキスト。
    static let accent     = fixed(0x5F5B76)

    /// 主ボタンの塗り。上に白文字を載せるので十分に暗くする。
    static let accentFill = fixed(0x6B6782)

    /// 活力（AP）。歩数に由来する資源なので、他と区別できる暖色にする。
    static let vigor      = fixed(0x9A6F4A)

    /// 危険・敗北。
    static let danger     = fixed(0x9B4A4A)

    /// 輪郭線。**アートと同じ「太く均一な暗い線」を UI 側にも引く**（§15-10）。
    /// 標準の SwiftUI 部品は線を持たないため、並べるとアートだけが浮いて
    /// 「絵は描き込んであるのに画面はただのアプリ」に見える。
    static let ink        = fixed(0x2E2A38)

    /// 本文。`.primary` の代わりに使う。
    static let text       = fixed(0x2E2A38)

    /// 補足。`.secondary` の代わりに使う。**紙の上で薄すぎない濃さ**にしている。
    static let textSoft   = fixed(0x6B6675)

    /// 線の太さ。アートの輪郭線と釣り合う値を実測で決めた。細いと弱く、太いと重い。
    static let strokeWidth: CGFloat = 2

    private static func fixed(_ rgb: Int) -> Color {
        Color(uiColor: UIColor(rgb: rgb))
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

// MARK: - 画集寄りの下地（§15-10）

/// 絵と同じ作法で囲んだ面。**全画面のカードはこれを使う。**
///
/// 標準の `.background(Theme.card, in: RoundedRectangle(...))` は線を持たないため、
/// 太い輪郭線のアートと並ぶと UI だけが別の作品に見える。塗り・線・落ち影を
/// 1か所に閉じ込めておき、調整はここだけで済むようにしている。
struct Panel: ViewModifier {
    var radius: CGFloat = 18
    var fill: Color = Theme.card
    var inset: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(inset)
            // **影は面にだけ落とす。** `.shadow` を content 側に付けると
            // 文字にも影が乗り、二重写しになって読めなくなる（実際にやらかした）。
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .shadow(color: Theme.ink.opacity(0.22), radius: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth)
            )
    }
}

extension View {
    func panel(radius: CGFloat = 18, fill: Color = Theme.card, inset: CGFloat = 16) -> some View {
        modifier(Panel(radius: radius, fill: fill, inset: inset))
    }
}

/// 主要な行動のボタン。押すと**沈んで影が消える**。
///
/// `.borderedProminent` は iOS の見た目そのものなので使わない。
/// 手応えは色ではなく **動き**で作る。押した瞬間に影の分だけ下がると、
/// 実際に押し込んだように見える。
struct InkButtonStyle: ButtonStyle {
    var fill: Color = Theme.accentFill
    var foreground: Color = .white
    var radius: CGFloat = 16

    private let depth: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .shadow(
                        color: Theme.ink.opacity(configuration.isPressed ? 0 : 0.9),
                        radius: 0,
                        y: configuration.isPressed ? 0 : depth
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth)
            )
            .offset(y: configuration.isPressed ? depth : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// 副次的な行動。塗りが薄いだけで、作法は主要ボタンと同じ。
struct InkSecondaryButtonStyle: ButtonStyle {
    var radius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.card)
                    .shadow(
                        color: Theme.ink.opacity(configuration.isPressed ? 0 : 0.7),
                        radius: 0,
                        y: configuration.isPressed ? 0 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth)
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// 行内に置く小さなボタン（装備の着脱・強化など）。
/// 幅を広げないので、`InkSecondaryButtonStyle` とは別に用意している。
struct InkChipButtonStyle: ButtonStyle {
    var fill: Color = Theme.card
    var foreground: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
                    .shadow(
                        color: Theme.ink.opacity(configuration.isPressed ? 0 : 0.7),
                        radius: 0,
                        y: configuration.isPressed ? 0 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth)
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// 見出し。下に短い線を引いて、章立てされた本のページに見せる。
struct SectionTitle: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.system(.headline, design: .rounded).weight(.heavy))
            Capsule()
                .fill(Theme.ink)
                .frame(width: 28, height: Theme.strokeWidth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 画面の枠組み

/// シートの見出し。**標準のナビゲーションバーは使わない。**
///
/// タイトルと「閉じる」が iOS の顔で出ると、開いた瞬間に設定画面のように見える。
/// 中身をどれだけ作り込んでも、最初に目に入るのがここなので効き目が大きい。
///
/// 右側には持ち物などを置ける（`trailing`）。無ければ左右の重みを揃えるため空ける。
struct GameHeader<Trailing: View>: View {
    let title: String
    var onClose: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth))
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(.title3, design: .rounded).weight(.heavy))

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

extension GameHeader where Trailing == EmptyView {
    init(title: String, onClose: @escaping () -> Void) {
        self.init(title: title, onClose: onClose, trailing: { EmptyView() })
    }
}

/// ヘッダーに置く持ち物の表示（活力・澱など）。
struct HeaderCounter: View {
    let systemImage: String
    let value: Int
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text("\(value)")
                .font(.system(.subheadline, design: .rounded).weight(.heavy).monospacedDigit())
                .contentTransition(.numericText())
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.card))
        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth))
    }
}

// MARK: - 数の演出（§15-11）

/// 数を回して見せる。
///
/// **「今日も無駄じゃなかった」は数字が動いて初めて伝わる。**
/// 完成値をいきなり置くと、同じ数でも受け取られ方がまるで違う。
struct RollingNumber: View, Animatable {
    var value: Double
    var format: (Int) -> String = { $0.formatted() }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(Int(value.rounded())))
    }
}

/// 表示された瞬間に 0 から回る数値。
struct CountUp: View {
    let target: Int
    var duration: Double = 0.7
    var format: (Int) -> String = { $0.formatted() }

    @State private var shown: Double = 0

    var body: some View {
        RollingNumber(value: shown, format: format)
            .onAppear {
                shown = 0
                withAnimation(.easeOut(duration: duration)) { shown = Double(target) }
            }
            // 値が後から変わる場合（歩数の再取得など）にも追従させる。
            .onChange(of: target) { _, newValue in
                withAnimation(.easeOut(duration: duration)) { shown = Double(newValue) }
            }
    }
}

// MARK: - 共通部品

/// 数値を1つ見せるための枠。ホームで多用する。
///
/// `count` を渡すと**開いた瞬間に 0 から回る**。文字列を渡す用途も残してある。
struct StatTile: View {
    var title: String
    var value: String? = nil
    var count: Int? = nil
    var systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Group {
                if let count {
                    CountUp(target: count)
                } else {
                    Text(value ?? "")
                }
            }
            // 桁が増えても幅が跳ねないよう等幅にする。数値が主役の画面なので効く。
            .font(.system(size: 26, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(tint)
            .contentTransition(.numericText())
            .minimumScaleFactor(0.6)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(radius: 14, inset: 14)
    }
}

/// HP や活気ゲージ。
///
/// **ゲージにも輪郭線を引く。** 線の無い細いバーは iOS の標準部品にしか見えず、
/// ここだけで画面全体の印象が「アプリ」に戻る。
struct MeterBar: View {
    var value: Double
    var tint: Color
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.16))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * (proxy.size.width - Theme.strokeWidth * 2))
                    .padding(Theme.strokeWidth)
                Capsule().strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.3), value: value)
    }
}
