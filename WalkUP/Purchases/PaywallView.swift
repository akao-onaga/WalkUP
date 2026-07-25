import StoreKit
import SwiftUI
import UIKit
import RevenueCat

/// 活力パスのペイウォール（画面 #6）。
///
/// 配色はダルモンのアート仕様（ART_PROMPTS.md）に合わせた低彩度のグレーバイオレット。
/// 派手な訴求はしない。本作の課金は「歩数を買う」ものではなく報酬トラックの強化なので、
/// 焦らせる表現を置くとコンセプトと矛盾する。
struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    benefits
                    purchaseArea
                    legalLinks
                    diagnostics
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("活力パス")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("復元") {
                        Task { handle(await purchases.restore()) }
                    }
                    .disabled(purchases.availability != .ready || purchases.isPurchasing)
                }
            }
            .task { await purchases.loadOfferings() }
            .alert("お知らせ", isPresented: showsResult) {
                Button("OK") { resultMessage = nil }
            } message: {
                Text(resultMessage ?? "")
            }
        }
    }

    // MARK: - 部品

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Palette.accent)
                .padding(.top, 8)

            Text("歩いた分を、もっと世界へ")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("活力パスは、討伐で得られる報酬を増やし、地域の復興を早く進めます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefit("素材の獲得量が増える", detail: "同じ歩数でも装備を早く強化できます。", icon: "cube")
            benefit("復興が早く進む", detail: "地域の活気ゲージの上昇量が増えます。", icon: "sparkles")
            benefit("歩数は買えません", detail: "歩いた事実だけがレベルと活力を決めます。ここは変わりません。", icon: "lock.shield")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func benefit(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Palette.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var purchaseArea: some View {
        switch purchases.availability {
        case .disabled:
            // クローン直後や CI ではここに入る。異常ではないので事実だけを伝える。
            unavailableNotice
        case .ready:
            if purchases.hasPass {
                activeNotice
            } else if let package = monthlyPackage {
                purchaseButton(for: package)
            } else if purchases.isLoadingOfferings {
                ProgressView().padding(.vertical, 24)
            } else {
                Text(purchases.errorMessage ?? "販売情報を取得できませんでした。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// ダッシュボードで `$rc_monthly` に `walkup_pass_monthly` を紐付け済み。
    /// 取れなかった場合は Offering 内の最初のパッケージにフォールバックする。
    private var monthlyPackage: Package? {
        guard let offering = purchases.currentOffering else { return nil }
        return offering.monthly ?? offering.availablePackages.first
    }

    private func purchaseButton(for package: Package) -> some View {
        VStack(spacing: 10) {
            Button {
                Task { handle(await purchases.purchase(package)) }
            } label: {
                HStack {
                    if purchases.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("\(package.storeProduct.localizedPriceString) / 月ではじめる")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accentFill)
            .disabled(purchases.isPurchasing)

            Text("自動更新サブスクリプションです。解約するまで毎月 \(package.storeProduct.localizedPriceString) が請求されます。解約は App Store の設定からいつでも行えます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var activeNotice: some View {
        Label("活力パスは有効です", systemImage: "checkmark.seal.fill")
            .font(.headline)
            .foregroundStyle(Palette.accent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private var unavailableNotice: some View {
        VStack(spacing: 6) {
            Label("課金機能は現在無効です", systemImage: "wrench.and.screwdriver")
                .font(.subheadline.bold())
            Text("RevenueCat の API キーが設定されていないビルドです。ゲーム本編は通常どおり遊べます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
    }

    /// App Store のガイドライン上、サブスクを販売する画面には
    /// 利用規約とプライバシーポリシーへの導線が必須。
    private var legalLinks: some View {
        HStack(spacing: 20) {
            Link("利用規約", destination: LegalURL.termsOfUse)
            Link("プライバシーポリシー", destination: LegalURL.privacyPolicy)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// 開発ビルド専用の診断表示。
    ///
    /// 実機のログを外から取れない場面が多いため、原因を画面から読めるようにしている。
    /// `#if DEBUG` で囲っているので Release ビルドには一切含まれない。
    @ViewBuilder
    private var diagnostics: some View {
        #if DEBUG
        if let detail = purchases.debugDetail {
            VStack(alignment: .leading, spacing: 6) {
                Label("診断（開発ビルドのみ）", systemImage: "stethoscope")
                    .font(.caption.bold())
                Text(detail)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.secondary)
        }
        #endif
    }

    // MARK: - 結果処理

    private var showsResult: Binding<Bool> {
        Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
    }

    private func handle(_ outcome: PurchaseManager.PurchaseOutcome) {
        switch outcome {
        case .purchased:
            resultMessage = "活力パスが有効になりました。"
        case .cancelled:
            break // ユーザーが自分で閉じた操作に、通知を返さない。
        case .failed(let message):
            resultMessage = message
        }
    }
}

// MARK: - 配色

/// ART_PROMPTS.md の STYLE SPEC と揃えた最小限のパレット。
/// ゲーム画面を作り込む段階で共通の Theme に昇格させる。
///
/// **背景色を固定するなら、文字色も必ずセットで面倒を見ること。**
/// 背景だけ固定して文字を `.primary` / `.secondary` のまま放置すると、
/// ダークモードで「明るい背景に白文字」になり読めなくなる。
/// ここでは背景側をモード追従にすることで、`.primary` / `.secondary` を
/// そのまま正しく機能させている。
private enum Palette {
    static let background = adaptive(light: 0xE8E4DC, dark: 0x1B1922)
    static let card       = adaptive(light: 0xF6F4EF, dark: 0x26232F)

    /// アイコンと強調テキスト。背景の明暗が反転するので、こちらも明度を入れ替える。
    static let accent     = adaptive(light: 0x5F5B76, dark: 0xADA5C9)

    /// 主ボタンの塗り。上に白文字を載せるため、両モードとも十分に暗い色で固定する。
    static let accentFill = adaptive(light: 0x6B6782, dark: 0x6B6782)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: Int) {
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue:  CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - 法務リンク

enum LegalURL {
    /// 独自の EULA を用意しない場合、Apple の標準 EULA を提示するのが正規の手順。
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// 本文は `docs/privacy-policy.html`。GitHub Pages で配信する。
    ///
    /// App Store Connect の「App のプライバシー」にも**同一の URL** を登録すること。
    /// 片方だけ変えると審査で指摘される。
    static let privacyPolicy = URL(string: "https://akao-onaga.github.io/WalkUP/privacy-policy.html")!
}

#Preview("ライト") {
    PaywallView()
        .environment(PurchaseManager())
}

// 背景色を固定している画面なので、ダーク側を常に並べて確認できるようにしておく。
#Preview("ダーク") {
    PaywallView()
        .environment(PurchaseManager())
        .preferredColorScheme(.dark)
}
