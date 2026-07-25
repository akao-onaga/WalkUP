import Foundation

/// RevenueCat ダッシュボードと App Store Connect に登録済みの識別子。
///
/// 文字列を各所に散らすと、ダッシュボード側の改名に追従できずに
/// 「課金は通るのに Entitlement が有効にならない」という最も気付きにくい不具合になる。
/// 参照は必ずここを経由する。
enum PurchaseIdentifiers {
    /// Entitlement ID。これが有効かどうかだけがアプリ内の判定基準。
    /// 商品を追加してもこの ID は変えないこと。
    static let passEntitlement = "pass"

    /// Offering ID。ダッシュボードで `current` に設定してあるため
    /// 通常は `offerings.current` で取れるが、取れなかった場合の保険として持つ。
    static let defaultOffering = "default"

    /// 月額パスの Product ID（App Store Connect 登録済み）。
    /// パッケージ経由で購入するため通常は使わないが、表示や検証で参照する。
    static let passMonthlyProduct = "walkup_pass_monthly"
}
