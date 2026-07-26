import SwiftUI
import UIKit

/// 戦闘（画面 #3）。§4.1 のとおり **3〜8秒のログ再生演出**。
///
/// 勝敗は `GameModel.startBattle` で既に確定している。ここは受け取ったログを
/// 順に再生するだけで、演出をどう変えても結果は変わらない。
///
/// ダルモンの立ち絵は1体1枚の静止画で、**動きは SwiftUI の変形だけで作っている**
/// （§15-2 / §10.1.1）。コマ送りのアートは1枚も使っていない。
/// **手応えは「動かす量」ではなく「止める瞬間」で作る。**
/// 攻撃 → 命中で一瞬止める（ヒットストップ）→ 揺らす、の順番が効く。
struct BattleView: View {
    let session: GameModel.BattleSession

    @Environment(\.dismiss) private var dismiss

    @State private var playerHP: Int
    @State private var enemyHP: Int
    @State private var lunge: Side?
    @State private var recoil: Side?
    @State private var flash: Side?
    @State private var screenFlash = 0.0
    @State private var cameraShake = 0.0
    @State private var floatingDamage: (side: Side, amount: Int, id: Int)?
    @State private var enemyDefeated = false
    @State private var isFinished = false
    /// 衝撃の跡。誰が殴られたか＋何手目か（同じ手で再生し直さないための id）。
    @State private var strike: (side: Side, id: Int)?
    /// 溶けた跡を残すか。撃破の直後だけ出す。
    @State private var puddle = false

    enum Side { case player, enemy }

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    init(session: GameModel.BattleSession) {
        self.session = session
        _playerHP = State(initialValue: session.player.maxHP)
        _enemyHP = State(initialValue: session.enemy.hp)
    }

    /// 1手あたりの再生間隔。§4.1 の「3〜8秒」に収まるよう手数から逆算する。
    /// 手数が多い戦闘ほど1手を短くし、総時間を一定に保つ。
    private var beat: Double {
        min(0.40, max(0.13, 4.5 / Double(max(1, session.log.turns.count))))
    }

    var body: some View {
        ZStack {
            RegionBackdrop(chapter: session.chapter)

            VStack(spacing: 16) {
                enemyHeader
                Spacer(minLength: 0)
                // **主人公は左、ダルモンは右。** 主人公は右へ歩いていく絵なので、
                // 左に置くと進む先に敵がいることになり、踏み込みの向きと絵が噛み合う。
                HStack(alignment: .bottom, spacing: 12) {
                    playerPane
                    enemyPane
                }
                // 下の余白は詰める。**上下均等に空けると2体が画面の上半分に寄り**、
                // 背景の道路だけが広く残って、立っている場所が宙に浮いて見える。
                Spacer(minLength: 0).frame(maxHeight: 40)
                playerFooter
            }
            .padding(20)
            // 画面全体を揺らす。個々の要素ではなく画面が動くと衝撃が伝わる。
            .offset(x: cameraShake)

            // 被弾の瞬間だけ画面に色を乗せる。ダメージの重さを一瞬で伝える。
            Theme.danger
                .opacity(screenFlash)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .task { await playback() }
        .fullScreenCover(isPresented: $isFinished) {
            ResultView(session: session) { dismiss() }
        }
    }

    // MARK: - 敵

    private var enemyHeader: some View {
        VStack(spacing: 10) {
            Text(session.enemy.name)
                .font(session.enemy.isBoss ? .title3.bold() : .headline)
                // 背景を暗く固定しているので、文字色も固定する。
                // .primary のままだとライトモードで黒字になり、暗い背景に埋もれる。
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)

            meter(
                value: Double(enemyHP) / Double(max(1, session.enemy.hp)),
                remaining: enemyHP,
                tint: Theme.danger
            )
        }
    }

    private var enemyPane: some View {
        // ダメージ数値は立ち絵の**上端**に出す。中央に置くと顔の上に重なり、
        // 被弾フラッシュで絵が明るく飛んでいる瞬間と重なって、
        // **頭が欠けたように見える**（実機で指摘を受けた）。
        ZStack(alignment: .top) {
            DarumonPortrait(enemy: session.enemy)
                // **左右に並べると使える幅が半分になる。** 高さだけを決めると
                // マドロミのような横長の個体が主人公側にはみ出すので、幅も縛る。
                .frame(maxWidth: portraitWidth, maxHeight: session.enemy.isBoss ? 250 : 175)
                .brightness(flash == .enemy ? 0.3 : 0)
                .shadow(color: .black.opacity(0.45), radius: 3)
                .modifier(IdleBob(active: !enemyDefeated))
                // 攻撃時は相手（左）へ、被弾時は後ろ（右）へ。
                .offset(
                    x: (lunge == .enemy ? -26 : 0) + (recoil == .enemy ? 16 : 0)
                )
                // 撃破は「溶け落ちる」。ダルモンは半分溶けた造形（ART_PROMPTS.md §2）
                // なので、倒れるより**縦に潰れて横へ広がる**方が絵と一致する。
                .scaleEffect(
                    x: enemyDefeated ? 1.25 : 1,
                    y: enemyDefeated ? 0.12 : 1,
                    anchor: .bottom
                )
                .opacity(enemyDefeated ? 0 : 1)

            if let damage = floatingDamage, damage.side == .enemy {
                DamageNumber(amount: damage.amount, tint: Theme.danger)
                    .id(damage.id)
                    .offset(y: -18)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .bottom)
        // 土煙は**足元**に出す。立ち絵の中央だと踏み抜いた感じにならない。
        .overlay(alignment: .bottom) {
            ZStack {
                // 溶けた跡。消えた場所に何か残らないと、ただ消えたように見える。
                Ellipse()
                    .fill(Theme.accent.opacity(puddle ? 0 : 0.55))
                    .frame(width: puddle ? 150 : 40, height: puddle ? 22 : 8)
                    .opacity(enemyDefeated ? 1 : 0)

                if let strike, strike.side == .enemy {
                    DustPuff().id(strike.id)
                }
            }
            .offset(y: -8)
        }
    }

    // MARK: - 主人公

    private var playerPane: some View {
        ZStack(alignment: .top) {
            HeroPortrait()
                .frame(maxWidth: portraitWidth, maxHeight: 175)
                // 明度を上げると髪の細い輪郭が白飛びして、頭が欠けたように見える。
                // 主人公の画素は変えず、外周の発光だけで被弾を表現する。
                .shadow(
                    color: flash == .player ? .white.opacity(0.85) : .clear,
                    radius: flash == .player ? 9 : 0
                )
                .shadow(color: .black.opacity(0.45), radius: 3)
                // 攻撃時は相手（右）へ、被弾時は後ろ（左）へ。
                .offset(
                    x: (lunge == .player ? 26 : 0) + (recoil == .player ? -16 : 0)
                )

            if let damage = floatingDamage, damage.side == .player {
                DamageNumber(amount: damage.amount, tint: Theme.danger)
                    .id(damage.id)
                    .offset(y: -18)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .bottom)
        .overlay(alignment: .bottom) {
            if let strike, strike.side == .player {
                DustPuff().id(strike.id).offset(y: -8)
            }
        }
    }

    private var playerFooter: some View {
        meter(
            value: Double(playerHP) / Double(max(1, session.player.maxHP)),
            remaining: playerHP,
            tint: Theme.accent
        )
    }

    /// HP バーと残量。敵と主人公で同じ形にして、左右のどちらの残量かを色で区別させる。
    private func meter(value: Double, remaining: Int, tint: Color) -> some View {
        HStack(spacing: 8) {
            MeterBar(value: value, tint: tint)
            Text("\(max(0, remaining))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 2)
                .frame(width: 44, alignment: .trailing)
        }
        .frame(maxWidth: 280)
    }

    /// 立ち絵1体あたりの幅。画面を左右で分けるので、片側はこれ以上広げられない。
    private var portraitWidth: CGFloat { 168 }

    // MARK: - 再生

    private func playback() async {
        impactLight.prepare()
        impactHeavy.prepare()

        for (index, turn) in session.log.turns.enumerated() {
            let attacker: Side = turn.attacker == .player ? .player : .enemy
            let target: Side = attacker == .player ? .enemy : .player

            // 1. 踏み込み。攻撃側が相手に向かって動く。
            withAnimation(.easeOut(duration: beat * 0.35)) { lunge = attacker }
            try? await Task.sleep(for: .seconds(beat * 0.35))

            // 2. 命中。ここで一瞬止めるのが手応えの本体。
            //    HP の減少・数値・フラッシュ・振動を同じ瞬間に集中させる。
            lunge = nil
            flash = target
            floatingDamage = (target, turn.damage, index)
            strike = (target, index)

            let isPlayerHurt = target == .player
            // 自分が受ける時だけ強く振動させる。すべて強くすると意味が薄れる。
            (isPlayerHurt ? impactHeavy : impactLight).impactOccurred()

            withAnimation(.easeOut(duration: beat * 0.2)) {
                recoil = target
                if target == .enemy { enemyHP = turn.defenderRemainingHP }
                else { playerHP = turn.defenderRemainingHP }
                if isPlayerHurt { screenFlash = 0.22 }
            }
            shakeCamera(strong: isPlayerHurt)

            try? await Task.sleep(for: .seconds(beat * 0.28))

            // 3. 戻す。
            withAnimation(.easeInOut(duration: beat * 0.3)) {
                recoil = nil
                flash = nil
                screenFlash = 0
            }
            try? await Task.sleep(for: .seconds(beat * 0.37))
            floatingDamage = nil
            strike = nil
        }

        // 決着の演出。
        if session.log.result == .victory {
            withAnimation(.easeIn(duration: 0.55)) { enemyDefeated = true }
            withAnimation(.easeOut(duration: 0.9)) { puddle = true }
            notify.notificationOccurred(.success)
            try? await Task.sleep(for: .seconds(0.7))
        } else {
            notify.notificationOccurred(.error)
            withAnimation(.easeOut(duration: 0.4)) { screenFlash = 0.35 }
            try? await Task.sleep(for: .seconds(0.5))
        }

        isFinished = true
    }

    /// 左右に数回振る。1回の大きな移動より、細かく往復させる方が衝撃に見える。
    private func shakeCamera(strong: Bool) {
        let amplitude: Double = strong ? 9 : 4
        let steps: [Double] = [amplitude, -amplitude * 0.7, amplitude * 0.4, 0]
        for (index, offset) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.045) {
                withAnimation(.linear(duration: 0.045)) { cameraShake = offset }
            }
        }
    }
}

/// 命中の瞬間に、相手の足元へ散る土煙。
///
/// **斬撃にはしない。** 主人公の武器は靴（§1.1）で、振るうのは足。
/// 弧を描く跡は刃の演出であり、この作品の設定と噛み合わない。
/// 踏み抜いた土煙と、地面に一瞬残る靴底の跡で見せる。
///
/// 色は白い閃光ではなく**道路に馴染む灰**にする。暗い背景に白を置くと、
/// そこだけ別のゲームの光り物に見える（§15-9 と同じ理由で、世界の色から離さない）。
struct DustPuff: View {
    @State private var spread = false

    private let puffs = 7

    var body: some View {
        ZStack {
            ForEach(0..<puffs, id: \.self) { index in
                let angle = Double(index) / Double(puffs) * .pi   // 上半分へは飛ばさない
                let distance: Double = spread ? 46 : 0
                Circle()
                    .fill(Color(white: 0.72).opacity(0.55))
                    .frame(width: 16 + Double(index % 3) * 6)
                    .offset(
                        x: cos(.pi + angle) * distance,
                        y: -sin(angle) * distance * 0.45
                    )
                    .scaleEffect(spread ? 1.5 : 0.4)
                    .opacity(spread ? 0 : 1)
            }

            // 靴底の跡。土煙だけだと「何かが当たった」で止まる。
            Footprint()
                .fill(Color(white: 0.55).opacity(spread ? 0 : 0.75))
                .frame(width: 34, height: 46)
                .rotationEffect(.degrees(-12))
                .scaleEffect(spread ? 1.1 : 0.9)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.32)) { spread = true }
        }
    }

    /// 厚底の靴底。溝を2本入れるだけで足跡として読める。
    private struct Footprint: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path(roundedRect: rect, cornerRadius: rect.width * 0.42)
            let grooveHeight = rect.height * 0.07
            for ratio in [0.34, 0.58] {
                path.addRect(CGRect(
                    x: rect.minX + rect.width * 0.16,
                    y: rect.minY + rect.height * ratio,
                    width: rect.width * 0.68,
                    height: grooveHeight
                ))
            }
            return path
        }
    }
}

/// ダルモンの立ち絵。
///
/// アセットが未生成の個体（ボスなど）は記号で代替する。
/// **アートが届いた順に絵が差し替わる**ので、量産の途中でも常にビルドが通る。
struct DarumonPortrait: View {
    let enemy: MasterData.Enemy

    var body: some View {
        if let name = enemy.assetName, UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: enemy.isBoss ? "cloud.moon.fill" : "cloud.fill")
                .font(.system(size: enemy.isBoss ? 112 : 86))
                .foregroundStyle(Theme.accent)
        }
    }
}

/// 戦闘の背景。章ごとに地域が変わる。
///
/// 背景は後処理で暗く沈めてある（`artpipeline --background`）。同じ明るさだと
/// 立ち絵の輪郭が背景に溶けるため。**上下を暗く落として**さらに立ち絵を浮かせ、
/// HPバーと数値の可読性も確保している。
struct RegionBackdrop: View {
    let chapter: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.background

                if UIImage(named: "bg\(chapter)") != nil {
                    Image("bg\(chapter)")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.45), .black.opacity(0.05), .black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// 主人公の立ち絵。
///
/// **主人公だけが暖色のアクセントを持つ**（ART_PROMPTS.md §3.8）。
/// 寒色に沈んだ世界で唯一動いている存在であることを、色で示している。
struct HeroPortrait: View {
    var body: some View {
        if UIImage(named: "hero") != nil {
            Image("hero")
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 74))
                .foregroundStyle(Theme.accentFill)
        }
    }
}

// MARK: - 演出の部品

/// 待機モーション。ゆっくりした上下動で「気だるさ」を出す。
/// ART_PROMPTS.md の sluggish / drowsy / inert という設定に合わせ、あえて遅くしている。
/// ゆっくり上下に揺れる待機モーション。戦闘のダルモンとホームの主人公で共用する。
struct IdleBob: ViewModifier {
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
    @State private var appeared = false

    var body: some View {
        Text("\(amount)")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            // 出た瞬間に大きく、すぐ縮む。数字が「弾ける」と当たった感じになる。
            .scaleEffect(appeared ? 1.0 : 1.6)
            .offset(y: appeared ? -46 : 0)
            .opacity(appeared ? 0 : 1)
            // 立ち絵の上に重なるので、影を濃くして数字と絵を分離する。
            // 薄いと絵の一部（頭の欠けなど）に見える。
            .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            .shadow(color: .black.opacity(0.5), radius: 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.12)) { appeared = false }
                withAnimation(.easeOut(duration: 0.55).delay(0.05)) { appeared = true }
            }
    }
}
