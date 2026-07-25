import Foundation
import Observation

/// 画面から触る唯一の窓口。
///
/// ゲームのルールは `StepConverter` / `BattleEngine` / `RewardCalculator` に
/// 純粋関数として置いてあり、ここはそれらを繋いで状態を保存するだけに留める。
/// 判断をここに書き始めるとテストできない場所にロジックが溜まる。
@MainActor
@Observable
final class GameModel {

    enum StepSource: String, CaseIterable, Identifiable {
        case healthKit = "ヘルスケア"
        case demo = "デモ (擬似データ)"
        var id: String { rawValue }
    }

    private(set) var state: GameState
    private(set) var recentSteps: [DailyStepCount] = []
    private(set) var todaySteps = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// 直近の変換結果。ホーム画面で「今回の増分」を出すために持つ。
    private(set) var lastOutcome: StepConverter.Outcome?

    /// 審査員向けのデモモード（§11-1）。シミュレータには歩数が存在しないため既定で必要。
    var source: StepSource = .healthKit {
        didSet { Task { await refresh() } }
    }

    /// 活力パスの有無。`PurchaseManager` から注入する。
    var hasPass = false

    private let store: GameStateStore

    init(store: GameStateStore = GameStateStore()) {
        self.store = store
        self.state = (try? store.load()) ?? GameState()
        ensureProgressExists()
    }

    private var provider: StepProvider {
        switch source {
        case .healthKit: HealthKitStepProvider()
        case .demo: MockStepProvider()
        }
    }

    // MARK: - 導出

    var player: PlayerState { state.player }
    var dregs: Int { state.materials[MaterialID.dregs] ?? 0 }
    var cores: Int { state.materials[MaterialID.core] ?? 0 }
    var coreShards: Int { state.materials[MaterialID.coreShard] ?? 0 }

    /// 次のレベルまでの進捗 0...1。
    var levelProgress: Double {
        let current = BalanceRules.expPerLevelSquared * player.level * player.level
        let next = BalanceRules.expPerLevelSquared * (player.level + 1) * (player.level + 1)
        guard next > current else { return 0 }
        return min(1, max(0, Double(player.exp - current) / Double(next - current)))
    }

    /// 挑戦できる最も新しい章。歩数ゲート（§5.1）で決まる。
    var unlockedChapter: Int {
        var unlocked = 1
        for chapter in 1...3 where player.cumulativeSteps >= MasterData.chapterGate(chapter) {
            unlocked = chapter
        }
        return unlocked
    }

    func progress(for chapter: Int) -> ChapterProgress {
        state.chapters.first { $0.chapterId == chapter } ?? ChapterProgress(chapterId: chapter)
    }

    /// 次に挑むノード。全クリア済みなら nil。
    var nextNode: (chapter: Int, index: Int)? {
        for chapter in 1...3 {
            guard player.cumulativeSteps >= MasterData.chapterGate(chapter) else { continue }
            let done = progress(for: chapter).nodeIndex
            if done < MasterData.nodesPerChapter {
                return (chapter, done + 1)
            }
        }
        return nil
    }

    func isNodeUnlocked(chapter: Int, index: Int) -> Bool {
        guard player.cumulativeSteps >= MasterData.chapterGate(chapter) else { return false }
        return index <= progress(for: chapter).nodeIndex + 1
    }

    func isNodeCleared(chapter: Int, index: Int) -> Bool {
        index <= progress(for: chapter).nodeIndex
    }

    var equippedItems: [Equipment] { state.equipment.filter(\.isEquipped) }

    var playerFighter: BattleEngine.Fighter {
        BattleEngine.playerFighter(level: player.level, equipment: state.equipment)
    }

    // MARK: - 歩数

    func requestAuthorizationAndRefresh() async {
        do {
            try await provider.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
    }

    /// 歩数を取り込み、EXP・AP・道標へ変換する。
    ///
    /// §2 の絶対ルール4「生成・計算はアプリを開いた時のみ」に従い、バックグラウンド処理は持たない。
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let provider = self.provider
        guard provider.isAvailable else {
            errorMessage = StepProviderError.healthDataUnavailable.errorDescription
            return
        }

        do {
            let recent = try await provider.recentDailySteps(days: 7)
            recentSteps = recent.sorted { $0.date > $1.date }
            todaySteps = recent.last(where: { Calendar.current.isDateInToday($0.date) })?.steps ?? 0
            errorMessage = nil

            let outcome = StepConverter.apply(
                dailySteps: recent.map { .init(date: $0.date, steps: $0.steps) },
                to: state.player,
                now: Date()
            )
            state.player = outcome.player
            state.pendingMilestones += outcome.gainedMilestones
            lastOutcome = outcome
            save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 道標（§18）

    /// 溜まった道標を一括で開封する。
    func openMilestones() -> [MilestoneOpener.Find] {
        let count = state.pendingMilestones
        guard count > 0 else { return [] }

        var generator = SystemRandomNumberGenerator()
        let finds = MilestoneOpener.open(
            count: count,
            unlockedChapter: unlockedChapter,
            alreadyUnlockedLore: Set(state.unlockedLore),
            using: &generator
        )

        for find in finds {
            switch find {
            case .lore(let id, _):
                state.unlockedLore.append(id)
            case .sighting(let darumonId, _):
                markSighted(darumonId)
            case .consumable(let id, _):
                state.consumables[id, default: 0] += 1
            case .coreShard:
                state.materials[MaterialID.coreShard, default: 0] += 1
            }
        }

        // かけらが揃ったら核に変える（§18.4）。
        let shards = state.materials[MaterialID.coreShard] ?? 0
        if shards >= BalanceRules.coreShardsPerCore {
            let converted = shards / BalanceRules.coreShardsPerCore
            state.materials[MaterialID.coreShard] = shards % BalanceRules.coreShardsPerCore
            state.materials[MaterialID.core, default: 0] += converted
        }

        state.pendingMilestones = 0
        save()
        return finds
    }

    private func markSighted(_ darumonId: String) {
        if let index = state.bestiary.firstIndex(where: { $0.darumonId == darumonId }) {
            state.bestiary[index].isSighted = true
            if state.bestiary[index].firstSeenAt == nil {
                state.bestiary[index].firstSeenAt = Date()
            }
        } else {
            state.bestiary.append(
                BestiaryEntry(darumonId: darumonId, isSighted: true, firstSeenAt: Date())
            )
        }
    }

    // MARK: - 戦闘

    enum BattleError: LocalizedError {
        case notEnoughAP(required: Int, current: Int)
        case nodeLocked

        var errorDescription: String? {
            switch self {
            case .notEnoughAP(let required, let current):
                return "活力が足りません（必要 \(required) / 所持 \(current)）。もう少し歩いてください。"
            case .nodeLocked:
                return "このノードはまだ挑めません。"
            }
        }
    }

    struct BattleSession {
        var chapter: Int
        var nodeIndex: Int
        var enemy: MasterData.Enemy
        var log: BattleEngine.Log
        var reward: RewardCalculator.Reward
        var player: BattleEngine.Fighter
    }

    /// 戦闘を解決する。
    ///
    /// **ここで勝敗まで確定させる**（§4.1）。UI は返ってきたログを再生するだけ。
    /// 演出の速度を変えても勝敗が変わらないのが利点。
    func startBattle(chapter: Int, nodeIndex: Int) throws -> BattleSession {
        guard isNodeUnlocked(chapter: chapter, index: nodeIndex) else {
            throw BattleError.nodeLocked
        }

        let node = MasterData.node(chapter: chapter, index: nodeIndex)
        let cost = node.enemy.apCost
        guard state.player.ap >= cost else {
            throw BattleError.notEnoughAP(required: cost, current: state.player.ap)
        }

        // 消費した AP は勝っても負けても返らない（§4.3）。
        state.player.ap -= cost

        let fighter = playerFighter
        var generator = SystemRandomNumberGenerator()
        let log = BattleEngine.resolve(
            player: fighter,
            enemy: BattleEngine.enemyFighter(node.enemy),
            using: &generator
        )

        // 既にクリア済みのノードを再挑戦した場合、装備は重複して配らない。
        let alreadyOwned = state.equipment.contains { $0.id == node.equipmentReward?.id }
        let reward = RewardCalculator.forBattle(
            enemy: node.enemy,
            result: log.result,
            hasPass: hasPass,
            equipmentReward: alreadyOwned ? nil : node.equipmentReward
        )

        apply(reward: reward, chapter: chapter, nodeIndex: nodeIndex, result: log.result, enemy: node.enemy)

        return BattleSession(
            chapter: chapter, nodeIndex: nodeIndex,
            enemy: node.enemy, log: log, reward: reward, player: fighter
        )
    }

    private func apply(
        reward: RewardCalculator.Reward,
        chapter: Int,
        nodeIndex: Int,
        result: BattleEngine.Result,
        enemy: MasterData.Enemy
    ) {
        if reward.dregs > 0 { state.materials[MaterialID.dregs, default: 0] += reward.dregs }
        if reward.cores > 0 { state.materials[MaterialID.core, default: 0] += reward.cores }

        if var item = reward.equipment {
            // 初めて手に入れた装備は、迷わせないよう自動で着ける。
            item.isEquipped = !state.equipment.contains { $0.slot == item.slot && $0.isEquipped }
            state.equipment.append(item)
        }

        if result == .victory {
            recordDefeat(of: enemy)
            advance(chapter: chapter, to: nodeIndex)
            addVitality(reward.vitality, chapter: chapter)
        }
        save()
    }

    private func recordDefeat(of enemy: MasterData.Enemy) {
        if let index = state.bestiary.firstIndex(where: { $0.darumonId == enemy.id }) {
            state.bestiary[index].defeatedCount += 1
            state.bestiary[index].isSighted = true
        } else {
            state.bestiary.append(
                BestiaryEntry(darumonId: enemy.id, defeatedCount: 1, isSighted: true, firstSeenAt: Date())
            )
        }
    }

    private func advance(chapter: Int, to nodeIndex: Int) {
        let index = state.chapters.firstIndex { $0.chapterId == chapter }
        if let index {
            // 再挑戦で進行が巻き戻らないようにする。
            state.chapters[index].nodeIndex = max(state.chapters[index].nodeIndex, nodeIndex)
            state.chapters[index].isCleared = state.chapters[index].nodeIndex >= MasterData.nodesPerChapter
        } else {
            state.chapters.append(
                ChapterProgress(
                    chapterId: chapter,
                    nodeIndex: nodeIndex,
                    isCleared: nodeIndex >= MasterData.nodesPerChapter
                )
            )
        }
    }

    private func addVitality(_ amount: Int, chapter: Int) {
        guard amount > 0 else { return }
        let regionId = "region_ch\(chapter)"
        if let index = state.regions.firstIndex(where: { $0.regionId == regionId }) {
            state.regions[index].vitality = min(
                BalanceRules.vitalityMax,
                state.regions[index].vitality + amount
            )
        } else {
            state.regions.append(
                RegionState(regionId: regionId, vitality: min(BalanceRules.vitalityMax, amount), isUnlocked: true)
            )
        }
    }

    // MARK: - 装備

    func toggleEquip(_ item: Equipment) {
        guard let index = state.equipment.firstIndex(where: { $0.id == item.id }) else { return }
        let willEquip = !state.equipment[index].isEquipped

        if willEquip {
            // 同じスロットは1つだけ。
            for other in state.equipment.indices where state.equipment[other].slot == item.slot {
                state.equipment[other].isEquipped = false
            }
        }
        state.equipment[index].isEquipped = willEquip
        save()
    }

    func canEnhance(_ item: Equipment) -> Bool {
        item.enhanceLevel < BalanceRules.maxEnhanceLevel
            && dregs >= BalanceRules.enhanceCost(currentLevel: item.enhanceLevel)
    }

    @discardableResult
    func enhance(_ item: Equipment) -> Bool {
        guard let index = state.equipment.firstIndex(where: { $0.id == item.id }) else { return false }
        let current = state.equipment[index]
        guard canEnhance(current) else { return false }

        state.materials[MaterialID.dregs, default: 0] -= BalanceRules.enhanceCost(currentLevel: current.enhanceLevel)
        state.equipment[index].enhanceLevel += 1
        save()
        return true
    }

    // MARK: - 永続化

    private func ensureProgressExists() {
        for chapter in 1...3 where !state.chapters.contains(where: { $0.chapterId == chapter }) {
            state.chapters.append(ChapterProgress(chapterId: chapter))
        }
    }

    private func save() {
        do {
            try store.save(state)
        } catch {
            // 保存に失敗してもプレイは続行させる。次の保存で回復する可能性がある。
            errorMessage = "進行状況を保存できませんでした: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    /// プレビューと動作確認用。歩数を直接足す。
    func debugAddSteps(_ steps: Int) {
        let outcome = StepConverter.apply(
            dailySteps: [.init(date: Date(), steps: state.player.todayCreditedSteps + steps)],
            to: state.player,
            now: Date()
        )
        state.player = outcome.player
        state.pendingMilestones += outcome.gainedMilestones
        lastOutcome = outcome
        save()
    }
    #endif
}
