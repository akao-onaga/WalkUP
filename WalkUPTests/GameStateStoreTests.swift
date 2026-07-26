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

    // MARK: - 旧データの移行

    @Test("役割ベースの図鑑IDが、種別ベースのIDに読み替えられる")
    func migratesLegacyBestiaryIDs() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 12体を実装する前のビルドが書いたファイル。
        var state = GameState()
        state.bestiary = [
            BestiaryEntry(darumonId: "zako_ch1_standard", defeatedCount: 3, isSighted: true),
            BestiaryEntry(darumonId: "zako_ch1_swift", defeatedCount: 0, isSighted: true),
            BestiaryEntry(darumonId: "boss_ch1", defeatedCount: 1, isSighted: true),
        ]
        try store.save(state)

        let loaded = try store.load()
        let ids = Set(loaded.bestiary.map(\.darumonId))
        // その章で同じ役割を持つ最初の個体（= 当時戦った相手）に寄る。
        #expect(ids == ["darari", "nemuke", "boss_ch1"])
        #expect(loaded.bestiary.first { $0.darumonId == "darari" }?.defeatedCount == 3)
        // 目撃のみの状態は保たれる。
        #expect(loaded.bestiary.first { $0.darumonId == "nemuke" }?.isShadowOnly == true)
    }

    @Test("移行先に既に記録があれば、討伐数を合算し初出日は古い方を残す")
    func migrationMergesIntoExistingEntry() throws {
        let old = Date(timeIntervalSince1970: 1_000_000)
        let recent = Date(timeIntervalSince1970: 2_000_000)

        var state = GameState()
        state.bestiary = [
            BestiaryEntry(darumonId: "zako_ch1_standard", defeatedCount: 2, isSighted: true, firstSeenAt: old),
            BestiaryEntry(darumonId: "darari", defeatedCount: 5, isSighted: true, firstSeenAt: recent),
        ]

        let migrated = state.migratingLegacyBestiaryIDs()
        #expect(migrated.bestiary.count == 1)
        #expect(migrated.bestiary[0].darumonId == "darari")
        #expect(migrated.bestiary[0].defeatedCount == 7)
        #expect(migrated.bestiary[0].firstSeenAt == old)
    }

    @Test("入手済みの装備の名前が、マスターデータから引き直される")
    func refreshesEquipmentNames() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 武器が「杖」だった頃に入手した装備。名前は保存データに焼き付いている。
        var state = GameState()
        state.equipment = [
            Equipment(id: "eq_ch1_weapon", name: "目覚めの杖", slot: .weapon,
                      hp: 0, atk: 7, def: 0, enhanceLevel: 3, isEquipped: true)
        ]
        try store.save(state)

        let item = try #require(try store.load().equipment.first)
        #expect(item.name == MasterData.equipment(chapter: 1, slot: .weapon).name)
        #expect(item.name.hasSuffix("靴"))
        // 強化段階と装備状態は触らない。
        #expect(item.enhanceLevel == 3)
        #expect(item.isEquipped)
    }

    @Test("移行は繰り返し通しても結果が変わらない")
    func migrationIsIdempotent() throws {
        var state = GameState()
        state.bestiary = [
            BestiaryEntry(darumonId: "zako_ch2_tough", defeatedCount: 1, isSighted: true),
            BestiaryEntry(darumonId: "akubi", defeatedCount: 4, isSighted: true),
        ]

        let once = state.migratingLegacyBestiaryIDs()
        #expect(once.bestiary == once.migratingLegacyBestiaryIDs().bestiary)
    }
}
