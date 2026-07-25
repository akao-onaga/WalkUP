import Foundation
import Testing
@testable import WalkUP

struct BattleEngineTests {

    @Test("ダメージは最低でも1（§4.2）")
    func damageNeverDropsBelowOne() {
        var generator = SeededGenerator(seed: 1)
        let damage = BattleEngine.damage(atk: 1, def: 999, using: &generator)
        #expect(damage >= 1)
    }

    @Test("DEF の半減は整数で切り捨てず、実数で計算する")
    func defenseHalvingUsesRealNumbers() {
        // ATK 20 / DEF 7 なら 20 - 3.5 = 16.5。整数除算だと 20 - 3 = 17 になり、
        // 防御側が 0.5 ぶん損をする。乱数幅を潰して素の値を確かめる。
        var generator = SeededGenerator(seed: 42)
        var samples: [Int] = []
        for _ in 0..<200 {
            samples.append(BattleEngine.damage(atk: 20, def: 7, using: &generator))
        }
        let average = Double(samples.reduce(0, +)) / Double(samples.count)
        // 16.5 × 平均1.0 = 16.5 前後に収束するはず。
        #expect(average > 15.5 && average < 17.5)
    }

    @Test("先攻は主人公固定（§4.2）")
    func playerAttacksFirst() {
        var generator = SeededGenerator(seed: 7)
        let log = BattleEngine.resolve(
            player: .init(name: "P", maxHP: 100, atk: 30, def: 10),
            enemy: .init(name: "E", maxHP: 100, atk: 10, def: 5),
            using: &generator
        )
        #expect(log.turns.first?.attacker == .player)
    }

    @Test("決着がつかない場合は30ターンで敗北（§4.2）")
    func stalemateCountsAsDefeat() {
        var generator = SeededGenerator(seed: 3)
        // 双方とも1ダメージしか通らず、HP が十分に高い状況。
        let log = BattleEngine.resolve(
            player: .init(name: "P", maxHP: 9_999, atk: 1, def: 500),
            enemy: .init(name: "E", maxHP: 9_999, atk: 1, def: 500),
            using: &generator
        )
        #expect(log.result == .defeat)
        #expect(log.turns.count == BalanceRules.maxTurns * 2)
    }

    @Test("同じシードなら結果が完全に再現される")
    func deterministicWithSameSeed() {
        func run() -> BattleEngine.Log {
            var generator = SeededGenerator(seed: 12_345)
            return BattleEngine.resolve(
                player: .init(name: "P", maxHP: 160, atk: 38, def: 22),
                enemy: BattleEngine.enemyFighter(MasterData.boss(chapter: 1)),
                using: &generator
            )
        }
        #expect(run() == run())
    }

    @Test("装備の強化がステータスに反映される（§17.7）")
    func enhancementAppliesToStats() {
        var weapon = MasterData.equipment(chapter: 1, slot: .weapon)
        #expect(weapon.effective.atk == 7)

        weapon.enhanceLevel = 5
        // 基礎値 × (1 + 0.20 × 5) = 2倍
        #expect(weapon.effective.atk == 14)
    }

    @Test("強化費用が §17.7 の式と一致する")
    func enhanceCostMatchesSpec() {
        #expect(BalanceRules.enhanceCost(currentLevel: 0) == 5)
        #expect(BalanceRules.enhanceCost(currentLevel: 1) == 20)
        #expect(BalanceRules.enhanceCost(currentLevel: 2) == 45)
        #expect(BalanceRules.enhanceCost(currentLevel: 3) == 80)
        #expect(BalanceRules.enhanceCost(currentLevel: 4) == 125)

        let total = (0..<BalanceRules.maxEnhanceLevel)
            .map(BalanceRules.enhanceCost(currentLevel:))
            .reduce(0, +)
        #expect(total == 275)
    }

    @Test("活力パスの倍率は切り上げ（§17.8）")
    func passMultiplierRoundsUp() {
        #expect(BalanceRules.applyPass(3, hasPass: false) == 3)
        #expect(BalanceRules.applyPass(3, hasPass: true) == 5)   // 4.5 → 5
        #expect(BalanceRules.applyPass(10, hasPass: true) == 15)
    }

    @Test("敗北時の持ち帰りは1/3で切り上げ（§4.3 / §17.8）")
    func salvageRoundsUp() {
        #expect(BalanceRules.salvaged(3) == 1)
        #expect(BalanceRules.salvaged(10) == 4)
    }

    // MARK: - マスターデータの整合

    @Test("第1章の装備合計が §4.4 の検証前提と一致する")
    func chapterOneEquipmentMatchesSpec() {
        let bonus = MasterData.fullSetBonus(chapter: 1)
        #expect(bonus.hp == 50)
        #expect(bonus.atk == 10)
        #expect(bonus.def == 5)

        // §4.4 の「主人公 Lv6・装備あり = HP160 / ATK38 / DEF22」
        var equipment = EquipmentSlot.allCases.map { MasterData.equipment(chapter: 1, slot: $0) }
        for index in equipment.indices { equipment[index].isEquipped = true }
        let fighter = BattleEngine.playerFighter(level: 6, equipment: equipment)

        #expect(fighter.maxHP == 160)
        #expect(fighter.atk == 38)
        #expect(fighter.def == 22)
    }

    @Test("装備なし Lv6 が §4.4 の検証前提と一致する")
    func chapterOneUnequippedMatchesSpec() {
        let fighter = BattleEngine.playerFighter(level: 6, equipment: [])
        #expect(fighter.maxHP == 110)
        #expect(fighter.atk == 28)
        #expect(fighter.def == 17)
    }
}
