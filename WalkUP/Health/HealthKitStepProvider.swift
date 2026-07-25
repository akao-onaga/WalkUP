import Foundation
import HealthKit

/// HealthKit から歩数を読み取る本番実装。
///
/// - Note: iOS シミュレータには歩数データが存在しないため、実機でしか
///   意味のある値は返らない。シミュレータでは `MockStepProvider` を使うこと。
final class HealthKitStepProvider: StepProvider {
    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            throw StepProviderError.healthDataUnavailable
        }
        do {
            // 書き込みは一切要求しない。読み取りのみ。
            try await store.requestAuthorization(toShare: [], read: [stepType])
        } catch {
            throw StepProviderError.authorizationFailed(error.localizedDescription)
        }
    }

    /// 読み取り許可のリクエストがまだ一度も行われていないか。
    ///
    /// HealthKit は読み取り拒否を秘匿するため、`.sharingDenied` は「拒否」を意味しない。
    /// 判定に使えるのは「まだ聞いていない (= .notDetermined)」かどうかだけ。
    func needsAuthorizationRequest() -> Bool {
        guard isAvailable else { return false }
        return store.authorizationStatus(for: stepType) == .notDetermined
    }

    func dailySteps(from startDate: Date, to endDate: Date) async throws -> [DailyStepCount] {
        guard isAvailable else {
            throw StepProviderError.healthDataUnavailable
        }

        let anchor = calendar.startOfDay(for: startDate)
        guard anchor <= endDate else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: anchor,
            end: endDate,
            options: .strictStartDate
        )

        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: stepType, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )

        do {
            let collection = try await descriptor.result(for: store)
            var results: [DailyStepCount] = []

            collection.enumerateStatistics(from: anchor, to: endDate) { statistics, _ in
                let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                results.append(
                    DailyStepCount(
                        date: self.calendar.startOfDay(for: statistics.startDate),
                        steps: Int(steps.rounded())
                    )
                )
            }
            return results
        } catch {
            throw StepProviderError.queryFailed(error.localizedDescription)
        }
    }
}
