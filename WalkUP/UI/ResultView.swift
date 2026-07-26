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

    /// 判子が押されたか。見出しの演出に使う。
    @State private var stamped = false
    /// 何行目まで報酬を出したか。**1行ずつ順に出す**（§15-11）。
    @State private var revealed = 0

    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()

    private var isVictory: Bool { session.log.result == .victory }

    /// 表示する報酬。演出のために**先に配列にしてから**1行ずつ出す。
    private var rewards: [(icon: String, title: String, amount: String)] {
        var rows: [(String, String, String)] = []
        if session.reward.dregs > 0 {
            rows.append(("cube", "怠惰の澱", "×\(session.reward.dregs)"))
        }
        if session.reward.cores > 0 {
            rows.append(("diamond.fill", "怠惰の核", "×\(session.reward.cores)"))
        }
        if session.reward.vitality > 0 {
            rows.append(("sparkles", "地域の活気", "+\(session.reward.vitality)"))
        }
        if let item = session.reward.equipment {
            rows.append(("shield.lefthalf.filled", item.name, "入手"))
        }
        return rows
    }

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
            .task { await playIntro() }
        }
    }

    /// 見出し。**判子を押すように出す。**
    ///
    /// 大きく傾いた状態から一気に縮んで正位置に収まる。
    /// 静止したまま出すと、討伐のたびに見る画面なのに何も起きていないように見える。
    private var banner: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isVictory ? Theme.accent.opacity(0.28) : Theme.danger.opacity(0.22))
                    .frame(width: 96, height: 96)
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth))

                Image(systemName: isVictory ? "checkmark.seal.fill" : "moon.zzz.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(isVictory ? Theme.accent : Theme.danger)
            }
            .scaleEffect(stamped ? 1 : 1.7)
            .rotationEffect(.degrees(stamped ? 0 : -14))
            .opacity(stamped ? 1 : 0)

            Text(isVictory ? "討伐した" : "活力が尽きて撤退した")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .scaleEffect(stamped ? 1 : 1.3)
                .opacity(stamped ? 1 : 0)

            Text("\(session.enemy.name) ・ \(session.log.turnCount / 2 + session.log.turnCount % 2) ターン")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(stamped ? 1 : 0)
        }
        .padding(.top, 12)
    }

    private var rewardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: isVictory ? "獲得" : "持ち帰った分")

            if rewards.isEmpty {
                Text("何も持ち帰れなかった")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(rewards.enumerated()), id: \.offset) { index, row in
                rewardRow(icon: row.icon, title: row.title, amount: row.amount)
                    // 出ていない行は場所だけ確保して隠す。高さが跳ねると読みづらい。
                    .opacity(index < revealed ? 1 : 0)
                    .offset(y: index < revealed ? 0 : 10)
            }

            if game.hasPass && isVictory {
                Divider()
                Label("活力パスにより素材と活気が 1.5倍", systemImage: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
                    .opacity(revealed >= rewards.count ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    private func rewardRow(icon: String, title: String, amount: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
            Spacer()
            Text(amount)
                .font(.system(.subheadline, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(Theme.accent)
        }
    }

    /// 判子 → 報酬を1行ずつ、の順で再生する。
    ///
    /// **触覚を1行ごとに返す。** 音の無いゲームなので、獲得の手応えはここでしか作れない。
    private func playIntro() async {
        impact.prepare()
        notify.prepare()

        withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { stamped = true }
        notify.notificationOccurred(isVictory ? .success : .warning)

        try? await Task.sleep(for: .seconds(0.28))
        for index in rewards.indices {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { revealed = index + 1 }
            impact.impactOccurred()
            try? await Task.sleep(for: .seconds(0.12))
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
            }
            .buttonStyle(InkButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}
