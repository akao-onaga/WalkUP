import Foundation

/// 歩数を擬似生成するモック実装。
///
/// 用途は3つあり、どれも本番運用上の意味がある:
/// 1. iOS シミュレータには歩数データが存在しないため、開発中の唯一の手段
/// 2. App Review の担当者は歩数ゼロの端末でアプリを開くため、その救済
/// 3. Shipaton の審査員が歩かずにゲーム全体を体験するためのデモモード
///
/// 日付をシードにした決定論的な生成なので、同じ日には必ず同じ値が返る。
/// （実行のたびに数字が変わるとデモとして使い物にならないため）
struct MockStepProvider: StepProvider {
    /// 1日あたりの歩数のレンジ
    var range: ClosedRange<Int>
    /// 「歩かなかった日」を再現する確率（0.0〜1.0）
    var restDayProbability: Double
    private let calendar: Calendar

    init(
        range: ClosedRange<Int> = 3_000...12_000,
        restDayProbability: Double = 0.15,
        calendar: Calendar = .current
    ) {
        self.range = range
        self.restDayProbability = restDayProbability
        self.calendar = calendar
    }

    var isAvailable: Bool { true }

    func requestAuthorization() async throws {
        // モックなので常に成功
    }

    func dailySteps(from startDate: Date, to endDate: Date) async throws -> [DailyStepCount] {
        var results: [DailyStepCount] = []
        var cursor = calendar.startOfDay(for: startDate)
        let last = calendar.startOfDay(for: endDate)

        while cursor <= last {
            results.append(DailyStepCount(date: cursor, steps: steps(for: cursor)))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return results
    }

    private func steps(for day: Date) -> Int {
        var generator = SeededGenerator(seed: UInt64(bitPattern: Int64(day.timeIntervalSince1970)))

        if Double.random(in: 0...1, using: &generator) < restDayProbability {
            // 休養日: 少しは歩いている
            return Int.random(in: 200...1_500, using: &generator)
        }

        let base = Int.random(in: range, using: &generator)

        // 今日だけは「時刻に応じて増えていく」ように見せる（デモの説得力のため）
        if calendar.isDateInToday(day) {
            let progress = elapsedFractionOfToday()
            return max(0, Int(Double(base) * progress))
        }
        return base
    }

    private func elapsedFractionOfToday(now: Date = Date()) -> Double {
        let start = calendar.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(start)
        return min(1.0, max(0.0, elapsed / 86_400))
    }
}

/// 決定論的な擬似乱数生成器（同じシードなら必ず同じ列を返す）
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // シードが 0 だと縮退するため必ず非ゼロにする
        self.state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        if state == 0 { state = 0x9E3779B97F4A7C15 }
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }
}
