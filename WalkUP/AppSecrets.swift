import Foundation

/// ビルド設定から注入された秘匿値へのアクセス。
///
/// 値の流れ:
/// `Secrets.xcconfig` → ビルド設定 `REVENUECAT_API_KEY` → Info.plist → ここ
///
/// `Secrets.xcconfig` は `.gitignore` 済みでリポジトリに入らない。
/// 未設定の場合は `nil` を返すので、呼び出し側で「課金機能を無効化する」等の
/// フォールバックを取れる（クローン直後でもアプリは起動する）。
enum AppSecrets {
    /// RevenueCat の Public app-specific API key（`appl_` で始まる）
    static var revenueCatAPIKey: String? {
        value(forKey: "RevenueCatAPIKey")
    }

    /// 課金機能を有効化できる状態かどうか
    static var isPurchasesConfigured: Bool {
        revenueCatAPIKey != nil
    }

    private static func value(forKey key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 未設定時は空文字が入るため、それも nil として扱う
        guard !trimmed.isEmpty, !trimmed.hasPrefix("appl_XXXX") else { return nil }
        return trimmed
    }
}
