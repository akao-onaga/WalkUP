import Foundation
import Testing
@testable import WalkUP

/// §3.4 が「日付変更をまたぐ場合・端末の日付を巻き戻された場合の両方を必ずテストすること」と
/// 名指ししている箇所。§15-7 でも自動テストの対象として指定されている。
struct StepConverterTests {

    /// タイムゾーンに依存すると、実行環境によって日境界がずれてテストが不安定になる。
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    private func date(_ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = hour
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    // MARK: - 基本の変換

    @Test("1歩 = 1 EXP、1,000歩 = 1 AP（§3.1）")
    func basicConversion() {
        let now = date(1)
        let outcome = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 4_000)],
            to: PlayerState(),
            now: now,
            calendar: calendar
        )

        #expect(outcome.gainedSteps == 4_000)
        #expect(outcome.player.exp == 4_000)
        #expect(outcome.gainedAP == 4)
        #expect(outcome.player.ap == 4)
    }

    @Test("1日の歩数は 30,000 で頭打ちになる（§3.1 チート対策）")
    func dailyCap() {
        let now = date(1)
        let outcome = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 99_999)],
            to: PlayerState(),
            now: now,
            calendar: calendar
        )

        #expect(outcome.gainedSteps == 30_000)
        #expect(outcome.gainedAP == 30)
    }

    @Test("レベルは 500 × N² から導かれる（§3.2）")
    func levelCurve() {
        #expect(PlayerState(cumulativeSteps: 0).level == 1)
        #expect(PlayerState(cumulativeSteps: 1_999).level == 1)
        #expect(PlayerState(cumulativeSteps: 2_000).level == 2)
        #expect(PlayerState(cumulativeSteps: 18_000).level == 6)
        #expect(PlayerState(cumulativeSteps: 50_000).level == 10)
        #expect(PlayerState(cumulativeSteps: 112_500).level == 15)
        #expect(PlayerState(cumulativeSteps: 200_000).level == 20)
    }

    @Test("章ゲートの到達レベルが §17.0 の表と一致する")
    func chapterGateLevels() {
        #expect(PlayerState(cumulativeSteps: MasterData.chapterGate(1)).level == 6)
        #expect(PlayerState(cumulativeSteps: MasterData.chapterGate(2)).level == 10)
        #expect(PlayerState(cumulativeSteps: MasterData.chapterGate(3)).level == 15)
    }

    // MARK: - 二重計上の防止（§3.4）

    @Test("同じ日に複数回取得しても、当日分は差分しか加算されない")
    func sameDayIsNotDoubleCounted() {
        let now = date(1, hour: 10)
        var state = PlayerState()

        state = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 3_000)],
            to: state, now: now, calendar: calendar
        ).player
        #expect(state.cumulativeSteps == 3_000)

        // 同じ歩数でもう一度取得しても増えない。
        let again = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 3_000)],
            to: state, now: date(1, hour: 11), calendar: calendar
        )
        #expect(again.gainedSteps == 0)
        #expect(again.player.cumulativeSteps == 3_000)

        // 歩数が増えていれば、その差分だけが入る。
        let more = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 5_000)],
            to: again.player, now: date(1, hour: 12), calendar: calendar
        )
        #expect(more.gainedSteps == 2_000)
        #expect(more.player.cumulativeSteps == 5_000)
    }

    @Test("日付をまたぐと当日カウンタが畳まれ、翌日の歩数が丸ごと入る")
    func dayRollover() {
        var state = PlayerState()

        state = StepConverter.apply(
            dailySteps: [.init(date: date(1), steps: 4_000)],
            to: state, now: date(1, hour: 23), calendar: calendar
        ).player

        // 翌日。前日ぶんは処理済みなので、当日の 4,000 だけが入る。
        let outcome = StepConverter.apply(
            dailySteps: [
                .init(date: date(1), steps: 4_000),
                .init(date: date(2), steps: 4_000),
            ],
            to: state, now: date(2, hour: 9), calendar: calendar
        )

        #expect(outcome.gainedSteps == 4_000)
        #expect(outcome.player.cumulativeSteps == 8_000)
        #expect(outcome.player.todayCreditedSteps == 4_000)
    }

    @Test("アプリを数日開かなかった場合、未処理の過去日がまとめて入る")
    func catchesUpMissedDays() {
        var state = PlayerState()
        state = StepConverter.apply(
            dailySteps: [.init(date: date(1), steps: 4_000)],
            to: state, now: date(1), calendar: calendar
        ).player

        let outcome = StepConverter.apply(
            dailySteps: [
                .init(date: date(1), steps: 4_000),
                .init(date: date(2), steps: 5_000),
                .init(date: date(3), steps: 6_000),
                .init(date: date(4), steps: 3_000),
            ],
            to: state, now: date(4), calendar: calendar
        )

        // 2日・3日は丸ごと、4日は当日ぶん。1日は処理済みなので入らない。
        #expect(outcome.gainedSteps == 5_000 + 6_000 + 3_000)
    }

    @Test("端末の時刻を巻き戻しても加算されない（§3.4）")
    func clockRollbackGrantsNothing() {
        var state = PlayerState()
        state = StepConverter.apply(
            dailySteps: [.init(date: date(10), steps: 8_000)],
            to: state, now: date(10), calendar: calendar
        ).player
        let before = state

        // 5日前に巻き戻して再取得。
        let outcome = StepConverter.apply(
            dailySteps: [.init(date: date(5), steps: 30_000)],
            to: state, now: date(5), calendar: calendar
        )

        #expect(outcome.gainedSteps == 0)
        #expect(outcome.gainedAP == 0)
        #expect(outcome.player.cumulativeSteps == before.cumulativeSteps)
        // 巻き戻しで進行状態が壊れないこと。
        #expect(outcome.player.lastProcessedDate == before.lastProcessedDate)
    }

    @Test("未来日の歩数は無視される")
    func futureDaysIgnored() {
        let outcome = StepConverter.apply(
            dailySteps: [
                .init(date: date(1), steps: 2_000),
                .init(date: date(9), steps: 30_000),
            ],
            to: PlayerState(), now: date(1), calendar: calendar
        )
        #expect(outcome.gainedSteps == 2_000)
    }

    @Test("初回起動では過去の履歴を取り込まない")
    func firstLaunchIgnoresHistory() {
        // ヘルスケアには過去の履歴がある。これを取り込むと初回起動の瞬間に
        // 数万歩が入り、「歩いて進める」という前提（§1）が崩れる。
        let outcome = StepConverter.apply(
            dailySteps: [
                .init(date: date(1), steps: 9_000),
                .init(date: date(2), steps: 9_000),
                .init(date: date(3), steps: 4_000),
            ],
            to: PlayerState(), now: date(3), calendar: calendar
        )

        #expect(outcome.gainedSteps == 4_000)
    }

    @Test("AP の端数は切り捨てで消えない")
    func apRemainderIsPreserved() {
        var state = PlayerState()
        let now = date(1)

        // 500歩ずつ2回 = 1,000歩 → 1 AP。都度割ると 0 AP になってしまう。
        state = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 500)],
            to: state, now: now, calendar: calendar
        ).player
        #expect(state.ap == 0)

        state = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 1_000)],
            to: state, now: date(1, hour: 13), calendar: calendar
        ).player
        #expect(state.ap == 1)
    }

    // MARK: - 道標（§18）

    @Test("道標は 500 歩ごとに1つ付与される（§18.3）")
    func milestonesPerFiveHundredSteps() {
        let now = date(1)
        let outcome = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 2_600)],
            to: PlayerState(), now: now, calendar: calendar
        )
        #expect(outcome.gainedMilestones == 5)
    }

    @Test("道標の日次上限は12個。これが無いと経済が壊れる（§18.3）")
    func milestoneDailyCap() {
        let now = date(1)
        let outcome = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 30_000)],
            to: PlayerState(), now: now, calendar: calendar
        )

        #expect(outcome.gainedMilestones == 12)
        // 歩数と AP は上限まで通常どおり入る。
        #expect(outcome.gainedSteps == 30_000)
        #expect(outcome.gainedAP == 30)
    }

    @Test("道標も当日分は差分しか付与されない")
    func milestonesAreNotDoubleCounted() {
        let now = date(1)
        var state = PlayerState()

        state = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 1_500)],
            to: state, now: now, calendar: calendar
        ).player
        #expect(state.milestoneCreditedToday == 3)

        let outcome = StepConverter.apply(
            dailySteps: [.init(date: now, steps: 2_000)],
            to: state, now: date(1, hour: 15), calendar: calendar
        )
        #expect(outcome.gainedMilestones == 1)
    }
}
