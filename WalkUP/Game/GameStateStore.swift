import Foundation

/// `GameState` の JSON 永続化（§15-1）。
///
/// SwiftData を採らなかったので、保存は「丸ごと書いて丸ごと読む」だけ。
/// クエリもリレーションも不要な規模（単一ユーザー・数十KB）なので、これで足りる。
struct GameStateStore {

    enum StoreError: Error, Equatable {
        /// 保存形式が新しすぎて読めない。将来のバージョンで書かれたファイル。
        case unsupportedSchema(found: Int, supported: Int)
    }

    /// このビルドが読める最大の `schemaVersion`。
    static let supportedSchemaVersion = 1

    private let fileURL: URL
    private let fileManager: FileManager

    /// - Parameter directory: 保存先。テストでは一時ディレクトリを渡す。
    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = directory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileURL = base.appendingPathComponent("GameState.json")
    }

    var url: URL { fileURL }

    /// 読み込む。ファイルが無ければ初期状態を返す（初回起動）。
    func load() throws -> GameState {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return GameState()
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 先にバージョンだけを見る。未知の新形式を古いコードで読むと、
        // 欠けたフィールドが既定値で埋まり、静かにデータを壊す。
        let probe = try decoder.decode(SchemaProbe.self, from: data)
        guard probe.schemaVersion <= Self.supportedSchemaVersion else {
            throw StoreError.unsupportedSchema(
                found: probe.schemaVersion,
                supported: Self.supportedSchemaVersion
            )
        }

        // 読み込みの直後に移行を通す。以降のコードは常に現行の形だけを見ればよい。
        return try decoder.decode(GameState.self, from: data)
            .migratingLegacyBestiaryIDs()
            .refreshingEquipmentNames()
    }

    /// 保存する。
    ///
    /// 一時ファイルへ書いてから差し替える。書き込み中に落ちても、
    /// 既存のセーブが半端な内容で上書きされない。
    func save(_ state: GameState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: .atomic)
        _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporaryURL)
    }

    private struct SchemaProbe: Decodable {
        var schemaVersion: Int
    }
}
