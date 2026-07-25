import Foundation

/// 歩数をゲーム資源へ変換する純粋関数（§3.1〜§3.4 / §18.5）。
///
/// **状態を書き換えず、新しい状態を返す。** 副作用が無いので、日付跨ぎや時刻の巻き戻しを
/// テストで自由に再現できる。§15-7 がこの箇所を自動テストの対象として名指ししている。
enum StepConverter {

    /// 1日分の歩数。`date` はその日の任意の時刻でよく、内部で日境界に丸める。
    struct DailySteps: Equatable {
        var date: Date
        var steps: Int

        init(date: Date, steps: Int) {
            self.date = date
            self.steps = steps
        }
    }

    /// 変換の結果。UI で「今回の増分」を見せるために差分も返す。
    struct Outcome: Equatable {
        var player: PlayerState
        /// 今回加算された歩数（上限適用後）。
        var gainedSteps: Int = 0
        /// 今回付与された AP。
        var gainedAP: Int = 0
        /// 今回付与された道標の数。
        var gainedMilestones: Int = 0
        /// レベルが上がったか。演出の出し分けに使う。
        var levelsGained: Int = 0
    }

    /// 歩数を状態へ反映する。
    ///
    /// - Parameters:
    ///   - dailySteps: 日別の歩数。順不同でよい。未来日は無視する。
    ///   - state: 現在のプレイヤー状態。
    ///   - now: 「今」の時刻。テストから注入する。
    ///   - calendar: 日境界の判定に使う。テストから固定タイムゾーンを注入する。
    static func apply(
        dailySteps: [DailySteps],
        to state: PlayerState,
        now: Date,
        calendar: Calendar = .current
    ) -> Outcome {
        var player = state
        let today = calendar.startOfDay(for: now)
        let levelBefore = player.level

        // 端末の時刻が巻き戻された場合は何も加算しない（§3.4）。
        // 巻き戻して再取得すれば無限に稼げてしまうため、前進以外は受け付けない。
        if let last = player.lastProcessedDate, today < calendar.startOfDay(for: last) {
            return Outcome(player: player)
        }

        // 日付が変わっていたら当日カウンタを畳む。
        // これを忘れると、翌日の歩数が前日の消化済み分だけ差し引かれて消える。
        if let last = player.lastProcessedDate, calendar.startOfDay(for: last) < today {
            player.todayCreditedSteps = 0
            player.milestoneCreditedToday = 0
        }

        let stepsBefore = player.cumulativeSteps
        var gainedMilestones = 0

        for bucket in dailySteps.sorted(by: { $0.date < $1.date }) {
            let day = calendar.startOfDay(for: bucket.date)

            // 未来日は無視。端末の時刻をいじられた場合に入り込む。
            guard day <= today else { continue }

            let capped = min(max(bucket.steps, 0), BalanceRules.dailyStepCap)
            let milestones = min(
                capped / BalanceRules.stepsPerMilestone,
                BalanceRules.milestoneDailyCap
            )

            if day == today {
                // 当日は差分だけを加算する（§3.4）。
                player.cumulativeSteps += max(0, capped - player.todayCreditedSteps)
                player.todayCreditedSteps = max(player.todayCreditedSteps, capped)

                gainedMilestones += max(0, milestones - player.milestoneCreditedToday)
                player.milestoneCreditedToday = max(player.milestoneCreditedToday, milestones)
            } else {
                // 過去日は「未処理のものだけ」を丸ごと加算する（§3.4）。
                //
                // 初回起動（lastProcessedDate == nil）では過去日を一切加算しない。
                // ヘルスケアには過去の履歴があるため、加算すると初回起動の瞬間に
                // 数万歩が入り、「歩いて進める」という前提（§1）が崩れる。
                guard let last = player.lastProcessedDate else { continue }
                guard day > calendar.startOfDay(for: last) else { continue }

                player.cumulativeSteps += capped
                gainedMilestones += milestones
            }
        }

        // AP は累計歩数から導く。差分を都度割ると端数が切り捨てで消える（§3.1）。
        let apBefore = stepsBefore / BalanceRules.stepsPerAP
        let apAfter = player.cumulativeSteps / BalanceRules.stepsPerAP
        let gainedAP = apAfter - apBefore
        player.ap += gainedAP

        // 前進のみ。巻き戻しは冒頭で弾いてある。
        player.lastProcessedDate = now

        return Outcome(
            player: player,
            gainedSteps: player.cumulativeSteps - stepsBefore,
            gainedAP: gainedAP,
            gainedMilestones: gainedMilestones,
            levelsGained: player.level - levelBefore
        )
    }
}
