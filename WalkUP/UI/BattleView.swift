import SwiftUI

/// 戦闘（画面 #3）。§4.1 のとおり **3〜8秒のログ再生演出**。
///
/// 勝敗は `GameModel.startBattle` で既に確定している。ここは受け取ったログを
/// 順に再生するだけで、演出の速度を変えても結果は変わらない。
///
/// アニメーションは SwiftUI の変形のみで作っている（§15-2 / §10.1.1）。
/// ダルモンは sluggish / drowsy / inert な存在なので、重く鈍い動きの方が設定に合う。
struct BattleView: View {
    let session: GameModel.BattleSession

    @Environment(\.dismiss) private var dismiss

    @State private var turnIndex = 0
    @State private var playerHP: Int
    @State private var enemyHP: Int
    @State private var shake: Side?
    @State private var flash: Side?
    @State private var floatingDamage: (side: Side, amount: Int)?
    @State private var isFinished = false

    enum Side { case player, enemy }

    init(session: GameModel.BattleSession) {
        self.session = session
        _playerHP = State(initialValue: session.player.maxHP)
        _enemyHP = State(initialValue: session.enemy.hp)
    }

    /// 1手あたりの再生間隔。§4.1 の「3〜8秒」に収まるよう、手数から逆算する。
    private var stepInterval: Double {
        let total = Double(session.log.turns.count)
        return min(0.45, max(0.12, 5.0 / max(1, total)))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                enemyPane
                Spacer(minLength: 0)
                playerPane
                if isFinished { resultButton }
            }
            .padding(20)
        }
        .task { await playback() }
        .fullScreenCover(isPresented: $isFinished) {
            ResultView(session: session) { dismiss() }
        }
    }

    // MARK: - 敵

    private var enemyPane: some View {
        VStack(spacing: 12) {
            Text(session.enemy.name)
                .font(.headline)

            MeterBar(value: Double(enemyHP) / Double(max(1, session.enemy.hp)), tint: Theme.danger)
                .frame(maxWidth: 260)

            ZStack {
                Image(systemName: session.enemy.isBoss ? "cloud.moon.fill" : "cloud.fill")
                    .font(.system(size: session.enemy.isBoss ? 110 : 84))
                    .foregroundStyle(Theme.accent)
                    .opacity(flash == .enemy ? 0.35 : 1)
                    .offset(x: shake == .enemy ? -10 : 0)
                    // 待機はゆっくりした上下動。気だるさを出す。
                    .modifier(IdleBob(active: !isFinished))

                if let damage = floatingDamage, damage.side == .enemy {
                    DamageNumber(amount: damage.amount, tint: Theme.danger)
                }
            }
            .frame(height: 150)
        }
    }

    // MARK: - 主人公

    private var playerPane: some View {
        VStack(spacing: 12) {
            ZStack {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.accentFill)
                    .opacity(flash == .player ? 0.35 : 1)
                    .offset(x: shake == .player ? 10 : 0)

                if let damage = floatingDamage, damage.side == .player {
                    DamageNumber(amount: damage.amount, tint: Theme.danger)
                }
            }
            .frame(height: 110)

            MeterBar(value: Double(playerHP) / Double(max(1, session.player.maxHP)), tint: Theme.accent)
                .frame(maxWidth: 260)

            Text("\(max(0, playerHP)) / \(session.player.maxHP)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var resultButton: some View {
        Button("結果を見る") { isFinished = true }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentFill)
    }

    // MARK: - 再生

    private func playback() async {
        for turn in session.log.turns {
            let target: Side = turn.attacker == .player ? .enemy : .player

            withAnimation(.easeOut(duration: 0.12)) {
                shake = target
                flash = target
            }
            floatingDamage = (target, turn.damage)

            withAnimation(.easeOut(duration: 0.2)) {
                if target == .enemy { enemyHP = turn.defenderRemainingHP }
                else { playerHP = turn.defenderRemainingHP }
            }

            try? await Task.sleep(for: .seconds(stepInterval * 0.5))
            withAnimation(.easeIn(duration: 0.12)) {
                shake = nil
                flash = nil
            }
            try? await Task.sleep(for: .seconds(stepInterval * 0.5))
            floatingDamage = nil
            turnIndex += 1
        }

        try? await Task.sleep(for: .seconds(0.4))
        isFinished = true
    }
}

// MARK: - 演出の部品

/// 待機モーション。ゆっくりした上下動で「気だるさ」を出す。
private struct IdleBob: ViewModifier {
    var active: Bool
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -6 : 6)
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: up)
            .onAppear { if active { up = true } }
    }
}

private struct DamageNumber: View {
    var amount: Int
    var tint: Color
    @State private var rise = false

    var body: some View {
        Text("\(amount)")
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .offset(y: rise ? -40 : 0)
            .opacity(rise ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { rise = true }
            }
    }
}
