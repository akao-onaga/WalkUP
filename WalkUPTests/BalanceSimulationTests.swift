import Foundation
import Testing
@testable import WalkUP

/// §17.11 で「未検証」として残した項目を実測で潰すためのシミュレーション。
///
/// §17 の検証は期待値のみで行っており、§4.2 の乱数（0.9〜1.1）を入れた場合の
/// 実際の勝率は確かめていない。「辛勝」の想定が「6割で負ける」に化ける可能性がある。
/// 紙の上では確かめられないため、ここで多数回まわして実測する。
struct BalanceSimulationTests {

    static let trials = 1_000

    struct Summary {
        var winRate: Double
        var averageTurns: Double
        var averageRemainingHPRate: Double
    }

    /// 同じ組み合わせを `trials` 回まわして統計を取る。
    static func simulate(
        player: BattleEngine.Fighter,
        enemy: BattleEngine.Fighter,
        seed: UInt64 = 20_260_726
    ) -> Summary {
        var generator = SeededGenerator(seed: seed)
        var wins = 0
        var totalTurns = 0
        var totalRemaining = 0

        for _ in 0..<trials {
            let log = BattleEngine.resolve(player: player, enemy: enemy, using: &generator)
            if log.result == .victory {
                wins += 1
                totalRemaining += log.playerRemainingHP
            }
            totalTurns += log.turnCount
        }

        return Summary(
            winRate: Double(wins) / Double(trials),
            averageTurns: Double(totalTurns) / Double(trials),
            averageRemainingHPRate: wins == 0
                ? 0
                : Double(totalRemaining) / Double(wins) / Double(player.maxHP)
        )
    }

    private static func equipped(chapter: Int) -> [Equipment] {
        EquipmentSlot.allCases.map {
            var item = MasterData.equipment(chapter: chapter, slot: $0)
            item.isEquipped = true
            return item
        }
    }

    /// 各章のボス戦で想定しているプレイヤーのレベル（§17.3）。
    private static let bossLevels = [1: 6, 2: 10, 3: 15]

    // MARK: - ボス

    @Test("ボス戦：装備なしでは勝てない（§4.4 の設計原則）", arguments: [1, 2, 3])
    func bossIsUnwinnableWithoutEquipment(chapter: Int) {
        let level = Self.bossLevels[chapter]!
        let summary = Self.simulate(
            player: BattleEngine.playerFighter(level: level, equipment: []),
            enemy: BattleEngine.enemyFighter(MasterData.boss(chapter: chapter))
        )

        print("[ボス 第\(chapter)章 / 装備なし] 勝率 \(String(format: "%.1f%%", summary.winRate * 100)) / 平均 \(String(format: "%.1f", summary.averageTurns)) ターン")

        // 「素の成長だけでは勝てない」が §4.4 の設計の核。ここが崩れると
        // 装備システムそのものが意味を失う。
        #expect(summary.winRate < 0.05)
    }

    @Test("ボス戦：装備ありなら辛勝できる（§17.3）", arguments: [1, 2, 3])
    func bossIsWinnableWithEquipment(chapter: Int) {
        let level = Self.bossLevels[chapter]!
        let summary = Self.simulate(
            player: BattleEngine.playerFighter(level: level, equipment: Self.equipped(chapter: chapter)),
            enemy: BattleEngine.enemyFighter(MasterData.boss(chapter: chapter))
        )

        print("[ボス 第\(chapter)章 / 装備あり] 勝率 \(String(format: "%.1f%%", summary.winRate * 100)) / 平均 \(String(format: "%.1f", summary.averageTurns)) ターン / 残HP \(String(format: "%.0f%%", summary.averageRemainingHPRate * 100))")

        // 「辛勝」の定義。確実に勝てるなら緊張が無く、5割を切るなら理不尽。
        // 実測は 87.0% / 81.9% / 79.1%（§17.12）。
        #expect(summary.winRate > 0.70)
        #expect(summary.winRate < 0.95)
    }

    @Test("ボス戦：強化すれば確実に勝てる。これが §17.7 の強化に意味を与える", arguments: [1, 2, 3])
    func enhancementMakesBossReliable(chapter: Int) {
        let level = Self.bossLevels[chapter]!
        var equipment = Self.equipped(chapter: chapter)
        for index in equipment.indices { equipment[index].enhanceLevel = 1 }

        let summary = Self.simulate(
            player: BattleEngine.playerFighter(level: level, equipment: equipment),
            enemy: BattleEngine.enemyFighter(MasterData.boss(chapter: chapter))
        )

        print("[ボス 第\(chapter)章 / 強化+1] 勝率 \(String(format: "%.1f%%", summary.winRate * 100))")

        // 装備を揃えるだけで確定勝利だと、素材を集める理由が消え、
        // 活力パス（素材1.5倍）の価値まで無意味になる。強化に役割を持たせている。
        #expect(summary.winRate > 0.98)
    }

    // MARK: - 雑魚

    @Test("雑魚：装備なしでも4ターン前後で倒せる（§17.2 の設計基準）", arguments: [1, 2, 3])
    func zakoMatchesFourTurnTarget(chapter: Int) {
        // §17.2 の基準Lv（各章の中間地点）。
        let level = [1: 4, 2: 8, 3: 12][chapter]!

        for role in MasterData.Role.allCases {
            let summary = Self.simulate(
                player: BattleEngine.playerFighter(level: level, equipment: []),
                enemy: BattleEngine.enemyFighter(MasterData.zako(chapter: chapter, role: role))
            )
            // turnCount は攻撃回数なので、往復1ターンあたり最大2件。
            let rounds = summary.averageTurns / 2

            print("[雑魚 第\(chapter)章 \(role.rawValue)] 勝率 \(String(format: "%.1f%%", summary.winRate * 100)) / 平均 \(String(format: "%.1f", rounds)) ターン / 残HP \(String(format: "%.0f%%", summary.averageRemainingHPRate * 100))")

            // 雑魚は周回対象。負けるようでは §2 の「罰を与えない」に反する。
            #expect(summary.winRate > 0.99)
            // §17.2 は「4ターンで倒せる」を基準にしている。
            #expect(rounds > 2.5 && rounds < 6.0)
        }
    }

    @Test("雑魚：削られるHPが §17.2 の想定（25%前後）に収まる", arguments: [1, 2, 3])
    func zakoDamageMatchesTarget(chapter: Int) {
        let level = [1: 4, 2: 8, 3: 12][chapter]!

        for role in MasterData.Role.allCases {
            let summary = Self.simulate(
                player: BattleEngine.playerFighter(level: level, equipment: []),
                enemy: BattleEngine.enemyFighter(MasterData.zako(chapter: chapter, role: role))
            )
            let lost = 1.0 - summary.averageRemainingHPRate
            // 25% 想定。低すぎると緊張が無く、高すぎると連戦できない。
            #expect(lost > 0.10 && lost < 0.45)
        }
    }

    // MARK: - セッション時間（§2）

    @Test("1日分のAPを使い切っても、戦闘の総ターン数がセッション3分に収まる")
    func dailySessionFitsInThreeMinutes() {
        // 1日4,000歩 = 4 AP = 雑魚4回（§17.1）。
        let level = 8
        var totalRounds = 0.0
        for role in [MasterData.Role.standard, .swift, .standard, .tough] {
            let summary = Self.simulate(
                player: BattleEngine.playerFighter(level: level, equipment: []),
                enemy: BattleEngine.enemyFighter(MasterData.zako(chapter: 2, role: role))
            )
            totalRounds += summary.averageTurns / 2
        }

        print("[1日分] 雑魚4回の合計 \(String(format: "%.1f", totalRounds)) ターン")

        // §4.1 は1戦3〜8秒。1ターンおよそ1秒として、4戦で30ターンを超えると
        // 演出だけで30秒を超え、§2 の「1セッション3分」を圧迫し始める。
        #expect(totalRounds < 30)
    }
}
