import SwiftUI

@main
struct WalkUPApp: App {
    /// 課金の状態は全画面から参照するため、アプリ生存期間で1つだけ持つ。
    @State private var purchases = PurchaseManager()

    /// ゲームの状態も同様。保存済みのセーブがあれば読み込まれる。
    @State private var game = GameModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(purchases)
                .environment(game)
                // **OS のライト／ダークには追従しない**（Theme の注記を参照）。
                // Info.plist の UIUserInterfaceStyle と揃えて二重に固定する。
                // 片方だけだと、シートやアラートなど OS 側が描く部分が反転する。
                .preferredColorScheme(.light)
                // リンクや標準ボタンの色も OS の青のままにしない。
                .tint(Theme.accent)
                // API キー未設定なら中で何もせず .disabled のまま進む。
                .task { purchases.configure() }
        }
    }
}
