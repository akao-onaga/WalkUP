import Foundation
import StoreKit
import RevenueCat

/// RevenueCat との唯一の接点。
///
/// 設計上の要点は2つ。
///
/// 1. **API キーが無くてもアプリは動く。** クローン直後や CI では `Secrets.xcconfig` が
///    存在せず `AppSecrets.revenueCatAPIKey` が `nil` になる。その場合は SDK を初期化せず
///    `.disabled` 状態で動き続ける。課金以外の全機能は影響を受けない。
/// 2. **課金状態の判定は Entitlement 一本。** 商品 ID で分岐すると、商品を増やしたり
///    価格を変えたりするたびにアプリ側の改修が必要になる。`pass` が有効かどうかだけを見る。
@MainActor
@Observable
final class PurchaseManager {
    /// SDK の初期化状態。
    enum Availability: Equatable {
        /// 正常に初期化された。
        case ready
        /// API キー未設定のため課金機能を無効化している（エラーではない）。
        case disabled
    }

    /// 購入操作の結果。呼び出し側が UI を出し分けるために使う。
    enum PurchaseOutcome: Equatable {
        case purchased
        case cancelled
        case failed(String)
    }

    private(set) var availability: Availability = .disabled

    /// 活力パスが有効かどうか。UI はこの1つだけを見ればよい。
    private(set) var hasPass = false

    /// ペイウォールに表示する Offering。未取得なら `nil`。
    private(set) var currentOffering: Offering?

    private(set) var isLoadingOfferings = false
    private(set) var isPurchasing = false

    /// 直近の失敗理由。取得失敗をペイウォールに出すために保持する。
    private(set) var errorMessage: String?

    /// 開発時のみ表示する、丸める前の生のエラー。
    ///
    /// `errorMessage` は利用者向けに文言を整形しており、原因の切り分けには使えない。
    /// 実機のログを外から取る手段が塞がっている場面が多いので、画面に出せるようにしておく。
    private(set) var debugDetail: String?

    private var customerInfoTask: Task<Void, Never>?

    // MARK: - 初期化

    /// アプリ起動時に一度だけ呼ぶ。
    ///
    /// `Purchases.configure` は多重呼び出しすると警告を出すため、既に構成済みなら何もしない。
    func configure() {
        guard availability != .ready else { return }

        guard let apiKey = AppSecrets.revenueCatAPIKey else {
            availability = .disabled
            return
        }

        #if DEBUG
        Purchases.logLevel = .info
        #else
        Purchases.logLevel = .error
        #endif

        Purchases.configure(withAPIKey: apiKey)
        availability = .ready

        observeCustomerInfo()
    }

    /// Entitlement の変化を購読する。
    ///
    /// 購入直後だけでなく、失効・返金・別端末での購入も同じ経路で流れてくるので、
    /// 状態更新はここに一本化する。購入メソッド側で `hasPass` を書き換えないこと。
    private func observeCustomerInfo() {
        customerInfoTask?.cancel()
        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard !Task.isCancelled else { return }
                self?.apply(info)
            }
        }
    }

    private func apply(_ info: CustomerInfo) {
        hasPass = info.entitlements[PurchaseIdentifiers.passEntitlement]?.isActive == true
    }

    // MARK: - 取得

    /// ペイウォール表示前に Offering を取得する。
    func loadOfferings() async {
        guard availability == .ready else { return }
        guard !isLoadingOfferings else { return }

        isLoadingOfferings = true
        errorMessage = nil
        debugDetail = nil
        defer { isLoadingOfferings = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            // ダッシュボードで current に設定済みだが、設定漏れに備えて ID でも引く。
            currentOffering = offerings.current
                ?? offerings.all[PurchaseIdentifiers.defaultOffering]

            if currentOffering == nil {
                errorMessage = "販売情報を取得できませんでした。時間をおいて再度お試しください。"
            }
            debugDetail = Self.detail(offerings: offerings, chosen: currentOffering)
        } catch {
            errorMessage = Self.message(for: error)
            debugDetail = Self.detail(for: error)
        }

        #if DEBUG
        // RevenueCat を迂回して StoreKit に直接聞く。原因の切り分けはこれで一意に決まる。
        debugDetail = [debugDetail, await Self.storeKitProbe()]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        #endif
    }

    #if DEBUG
    /// StoreKit へ直接の商品照会。
    ///
    /// RevenueCat の `configurationError` は「商品が取れない」としか言わず、
    /// 原因が Apple 側か RevenueCat の設定側かを区別できない。ここで直接聞くことで分離する。
    ///
    /// - 0件 → Apple 側。ASC の伝播待ちか、商品／契約の状態
    /// - 1件 → Apple 側は正常。RevenueCat ダッシュボードの設定が原因
    private static func storeKitProbe() async -> String {
        var lines = ["--- StoreKit 直接照会（RevenueCat を迂回）---"]
        lines.append("storefront: \(await Storefront.current?.countryCode ?? "不明")")

        do {
            let products = try await StoreKit.Product.products(
                for: [PurchaseIdentifiers.passMonthlyProduct]
            )
            if products.isEmpty {
                lines.append("結果: 0件")
                lines.append("→ Apple 側から商品が返っていない。RevenueCat の設定は無関係。")
            } else {
                for product in products {
                    lines.append("結果: \(product.id) / \(product.displayPrice)")
                }
                lines.append("→ Apple 側は正常。RevenueCat ダッシュボードの設定が原因。")
            }
        } catch {
            lines.append("結果: 例外 \(error)")
        }
        return lines.joined(separator: "\n")
    }
    #endif

    /// 取得できた場合の内訳。Offering は返るのに商品が0件、というのが最も多い失敗の形。
    private static func detail(offerings: Offerings, chosen: Offering?) -> String {
        var lines = ["offerings.all: \(offerings.all.keys.sorted().joined(separator: ", "))"]
        lines.append("current: \(offerings.current?.identifier ?? "nil")")
        if let chosen {
            lines.append("packages: \(chosen.availablePackages.count)")
            for package in chosen.availablePackages {
                lines.append("  - \(package.identifier) → \(package.storeProduct.productIdentifier)")
            }
            if chosen.availablePackages.isEmpty {
                lines.append("⚠️ Offering は取れたが商品が0件。StoreKit が商品を引けていない。")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func detail(for error: Error) -> String {
        guard let rcError = error as? RevenueCat.ErrorCode else {
            return String(describing: error)
        }
        var lines = ["ErrorCode: \(rcError)"]
        lines.append("description: \(rcError.localizedDescription)")
        let nsError = rcError as NSError
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] {
            lines.append("underlying: \(underlying)")
        }
        if let readable = nsError.userInfo["readable_error_code"] {
            lines.append("readable: \(readable)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 購入・復元

    func purchase(_ package: Package) async -> PurchaseOutcome {
        guard availability == .ready else {
            return .failed("課金機能が利用できない状態です。")
        }
        guard !isPurchasing else { return .cancelled }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            // hasPass は customerInfoStream 経由で更新されるためここでは触らない。
            return .purchased
        } catch {
            let message = Self.message(for: error)
            errorMessage = message
            return .failed(message)
        }
    }

    /// 機種変更・再インストール時の復元。
    /// App Store の審査ガイドライン上、サブスクを売る画面には必ず導線が必要。
    @discardableResult
    func restore() async -> PurchaseOutcome {
        guard availability == .ready else {
            return .failed("課金機能が利用できない状態です。")
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return hasPass ? .purchased : .failed("復元できる購入が見つかりませんでした。")
        } catch {
            let message = Self.message(for: error)
            errorMessage = message
            return .failed(message)
        }
    }

    // MARK: - エラー整形

    /// RevenueCat のエラーはそのまま出すと英語かつ内部的なので、日本語に寄せる。
    private static func message(for error: Error) -> String {
        guard let rcError = error as? RevenueCat.ErrorCode else {
            return error.localizedDescription
        }
        switch rcError {
        case .networkError, .offlineConnectionError:
            return "通信に失敗しました。電波の良い場所で再度お試しください。"
        case .purchaseNotAllowedError:
            return "この端末では購入が許可されていません。"
        case .paymentPendingError:
            return "購入の承認待ちです。完了すると自動的に反映されます。"
        case .productNotAvailableForPurchaseError, .configurationError:
            return "現在この商品を購入できません。時間をおいて再度お試しください。"
        default:
            return rcError.localizedDescription
        }
    }
}
