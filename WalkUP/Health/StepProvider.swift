import Foundation

/// 1日単位に丸めた歩数。
///
/// ゲームロジックは常にこの粒度でのみ歩数を扱う。HealthKit の生サンプルを
/// 直接参照しないことで、(1) モックへの差し替え (2) 1日あたりの上限による
/// チート対策 (3) 二重計上の防止 を1箇所に閉じ込められる。
struct DailyStepCount: Identifiable, Hashable, Sendable {
    /// その日の 00:00（端末のカレンダー基準）
    let date: Date
    let steps: Int

    var id: Date { date }
}

enum StepProviderError: LocalizedError {
    case healthDataUnavailable
    case authorizationFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "この端末ではヘルスケアデータを利用できません。"
        case .authorizationFailed(let detail):
            return "ヘルスケアへのアクセス許可を取得できませんでした: \(detail)"
        case .queryFailed(let detail):
            return "歩数の取得に失敗しました: \(detail)"
        }
    }
}

/// 歩数の供給元。
///
/// 本番は `HealthKitStepProvider`、シミュレータ／審査員向けデモは
/// `MockStepProvider` を差す。ゲーム側はこのプロトコルにのみ依存する。
protocol StepProvider: Sendable {
    /// 歩数を取得できる環境か（実機かどうか、ヘルスケア対応端末かどうか）
    var isAvailable: Bool { get }

    /// 読み取り許可をリクエストする。
    ///
    /// - Important: HealthKit は「拒否された」ことをアプリ側に伝えない仕様のため、
    ///   このメソッドが成功しても歩数が 0 件で返る可能性がある。
    ///   許可されなかったケースは「歩数が取れない」として扱うこと。
    func requestAuthorization() async throws

    /// `startDate` から `endDate` までの日別歩数を返す。
    /// 歩数が記録されていない日は `steps: 0` として含める。
    func dailySteps(from startDate: Date, to endDate: Date) async throws -> [DailyStepCount]
}

extension StepProvider {
    /// 今日（00:00 から現在まで）の歩数
    func todaySteps(calendar: Calendar = .current, now: Date = Date()) async throws -> Int {
        let start = calendar.startOfDay(for: now)
        return try await dailySteps(from: start, to: now).first?.steps ?? 0
    }

    /// 直近 `days` 日分（今日を含む）の日別歩数
    func recentDailySteps(
        days: Int,
        calendar: Calendar = .current,
        now: Date = Date()
    ) async throws -> [DailyStepCount] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }
        return try await dailySteps(from: start, to: now)
    }
}
