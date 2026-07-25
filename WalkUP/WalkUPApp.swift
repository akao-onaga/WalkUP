import SwiftUI

@main
struct WalkUPApp: App {
    /// 課金の状態は全画面から参照するため、アプリ生存期間で1つだけ持つ。
    @State private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchases)
                // API キー未設定なら中で何もせず .disabled のまま進む。
                .task { purchases.configure() }
        }
    }
}
