import Foundation
import Observation

/// 歩数取得の疎通確認用モデル。
/// 本実装ではここがゲームの「活力／経験値」変換層に置き換わる。
@MainActor
@Observable
final class StepDashboardModel {
    enum Source: String, CaseIterable, Identifiable {
        case healthKit = "ヘルスケア"
        case mock = "デモ (擬似データ)"
        var id: String { rawValue }
    }

    /// 1日に加算できる歩数の上限。
    /// 端末を振る・乗り物での誤検出といったチートの影響を抑える。
    static let dailyStepCap = 30_000

    /// 第1章の解放に必要な累計歩数（企画上の暫定値）
    static let chapterOneGoal = 20_000

    private(set) var today: Int = 0
    private(set) var history: [DailyStepCount] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isHealthDataAvailable = true

    var source: Source = .healthKit {
        didSet { Task { await reload() } }
    }

    private var provider: StepProvider {
        switch source {
        case .healthKit: HealthKitStepProvider()
        case .mock: MockStepProvider()
        }
    }

    /// 上限を適用した直近7日の累計（章ゲートの判定に使う想定）
    var cappedTotal: Int {
        history.reduce(0) { $0 + min($1.steps, Self.dailyStepCap) }
    }

    var chapterOneProgress: Double {
        min(1.0, Double(cappedTotal) / Double(Self.chapterOneGoal))
    }

    func requestAuthorizationAndLoad() async {
        errorMessage = nil
        do {
            try await provider.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
        }
        await reload()
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }

        let provider = self.provider
        isHealthDataAvailable = provider.isAvailable

        guard provider.isAvailable else {
            errorMessage = StepProviderError.healthDataUnavailable.errorDescription
            history = []
            today = 0
            return
        }

        do {
            let recent = try await provider.recentDailySteps(days: 7)
            history = recent.sorted { $0.date > $1.date }
            today = recent.last(where: { Calendar.current.isDateInToday($0.date) })?.steps ?? 0
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            history = []
            today = 0
        }
    }
}
