import Foundation
import Testing
@testable import WalkUP

struct GameStateStoreTests {

    /// テストごとに独立した一時ディレクトリを使う。
    private func makeStore() throws -> (GameStateStore, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (GameStateStore(directory: directory), directory)
    }

    @Test("保存していない状態を読むと初期状態が返る（初回起動）")
    func loadWithoutFileReturnsInitialState() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let state = try store.load()
        #expect(state.player.cumulativeSteps == 0)
        #expect(state.player.level == 1)
        #expect(state.schemaVersion == GameStateStore.supportedSchemaVersion)
    }

    @Test("保存した状態がそのまま復元される")
    func roundTrip() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        var state = GameState()
        state.player.cumulativeSteps = 23_456
        state.player.ap = 7
        state.player.lastProcessedDate = Date(timeIntervalSince1970: 1_785_000_000)
        state.player.todayCreditedSteps = 3_456
        state.player.milestoneCreditedToday = 6
        state.materials[MaterialID.dregs] = 42
        state.consumables["potion"] = 2
        state.unlockedLore = ["lore_001", "lore_002"]
        state.equipment = [MasterData.equipment(chapter: 1, slot: .weapon)]
        state.chapters = [ChapterProgress(chapterId: 1, nodeIndex: 3)]
        state.regions = [RegionState(regionId: "r1", vitality: 20, isUnlocked: true)]
        state.bestiary = [BestiaryEntry(darumonId: "d1", defeatedCount: 2, isSighted: true)]

        try store.save(state)
        let restored = try store.load()

        #expect(restored == state)
    }

    @Test("上書き保存しても壊れない")
    func overwrite() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        var state = GameState()
        state.player.cumulativeSteps = 100
        try store.save(state)

        state.player.cumulativeSteps = 200
        try store.save(state)

        #expect(try store.load().player.cumulativeSteps == 200)
    }

    @Test("将来の形式で書かれたファイルは、既定値で埋めずにエラーにする")
    func rejectsNewerSchema() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 新しいバージョンのアプリが書いたファイルを、古いコードが読む状況。
        // 素直にデコードすると未知フィールドが落ち、既定値で上書き保存されて
        // 静かにデータを壊す。読めないことを明示する。
        var state = GameState()
        state.schemaVersion = GameStateStore.supportedSchemaVersion + 1
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: store.url)

        #expect(throws: GameStateStore.StoreError.self) {
            try store.load()
        }
    }
}
