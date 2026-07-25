import SwiftUI

/// 結果／報酬（画面 #5）。
///
/// §4.3 のとおり敗北しても全損させない。そして
/// **敗北画面には必ず「装備を強化する」への導線を置く。**
/// 「準備不足で負けた → 整えて出直す」という因果を理解させることが目的。
struct ResultView: View {
    let session: GameModel.BattleSession
    let onClose: () -> Void

    @Environment(GameModel.self) private var game
    @State private var isShowingEquipment = false

    private var isVictory: Bool { session.log.result == .victory }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    banner
                    rewardCard
                    if !isVictory { retryGuidance }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: onClose)
                }
            }
            .sheet(isPresented: $isShowingEquipment) { EquipmentView() }
        }
    }

    private var banner: some View {
        VStack(spacing: 10) {
            Image(systemName: isVictory ? "checkmark.seal.fill" : "moon.zzz.fill")
                .font(.system(size: 52))
                .foregroundStyle(isVictory ? Theme.accent : Theme.danger)

            Text(isVictory ? "討伐した" : "活力が尽きて撤退した")
                .font(.title2.bold())

            Text("\(session.enemy.name) ・ \(session.log.turnCount / 2 + session.log.turnCount % 2) ターン")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private var rewardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isVictory ? "獲得" : "持ち帰った分")
                .font(.caption)
                .foregroundStyle(.secondary)

            if session.reward.isEmpty {
                Text("何も持ち帰れなかった")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if session.reward.dregs > 0 {
                rewardRow(icon: "cube", title: "怠惰の澱", amount: "×\(session.reward.dregs)")
            }
            if session.reward.cores > 0 {
                rewardRow(icon: "diamond.fill", title: "怠惰の核", amount: "×\(session.reward.cores)")
            }
            if session.reward.vitality > 0 {
                rewardRow(icon: "sparkles", title: "地域の活気", amount: "+\(session.reward.vitality)")
            }
            if let item = session.reward.equipment {
                rewardRow(icon: "shield.lefthalf.filled", title: item.name, amount: "入手")
            }

            if game.hasPass && isVictory {
                Divider()
                Label("活力パスにより素材と活気が 1.5倍", systemImage: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func rewardRow(icon: String, title: String, amount: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
            Spacer()
            Text(amount)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.accent)
        }
    }

    /// §4.3 が要求する導線。ここを省くと「なぜ負けたのか」が伝わらない。
    private var retryGuidance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("装備を整えれば勝てる")
                .font(.headline)
            Text("消費した活力は戻りません。ですが素材は残りました。装備を強化してから、もう一度挑んでください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                isShowingEquipment = true
            } label: {
                Label("装備を強化する", systemImage: "hammer.fill")
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentFill)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}
