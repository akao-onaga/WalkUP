import Foundation

/// 自動戦闘の解決（§4.1〜§4.3）。
///
/// **純粋関数として書く。** §4.1 のとおり勝敗は準備段階で決まっており、戦闘は
/// ログの再生でしかない。先に結果とログを丸ごと算出し、UI はそれを再生するだけにする。
/// こうすると演出の速度や見た目を変えても勝敗が変わらず、バランス検証も
/// 画面なしで何千回でも回せる。
enum BattleEngine {

    struct Fighter: Equatable {
        var name: String
        var maxHP: Int
        var atk: Int
        var def: Int
    }

    enum Side: String, Equatable {
        case player
        case enemy
    }

    struct Turn: Equatable {
        var index: Int
        var attacker: Side
        var damage: Int
        /// 攻撃を受けた側の残りHP。
        var defenderRemainingHP: Int
    }

    enum Result: String, Equatable {
        case victory
        /// HP が尽きた、または §4.2 の30ターン上限に達した（「活力が尽きて撤退」）。
        case defeat
    }

    struct Log: Equatable {
        var turns: [Turn]
        var result: Result
        var playerRemainingHP: Int

        var turnCount: Int { turns.count }
    }

    /// 戦闘を解決する。
    ///
    /// - Parameter generator: 乱数源。テストでは決定論的なものを渡して再現性を得る。
    static func resolve(
        player: Fighter,
        enemy: Fighter,
        variance: ClosedRange<Double> = BalanceRules.damageVarianceRange,
        using generator: inout some RandomNumberGenerator
    ) -> Log {
        var playerHP = player.maxHP
        var enemyHP = enemy.maxHP
        var turns: [Turn] = []

        // 先攻は主人公固定（§4.2）。
        for index in 1...BalanceRules.maxTurns {
            let toEnemy = damage(atk: player.atk, def: enemy.def, variance: variance, using: &generator)
            enemyHP -= toEnemy
            turns.append(Turn(
                index: index, attacker: .player,
                damage: toEnemy, defenderRemainingHP: max(0, enemyHP)
            ))
            if enemyHP <= 0 {
                return Log(turns: turns, result: .victory, playerRemainingHP: playerHP)
            }

            let toPlayer = damage(atk: enemy.atk, def: player.def, variance: variance, using: &generator)
            playerHP -= toPlayer
            turns.append(Turn(
                index: index, attacker: .enemy,
                damage: toPlayer, defenderRemainingHP: max(0, playerHP)
            ))
            if playerHP <= 0 {
                return Log(turns: turns, result: .defeat, playerRemainingHP: 0)
            }
        }

        // 30ターンで決着せず（§4.2）。
        return Log(turns: turns, result: .defeat, playerRemainingHP: max(0, playerHP))
    }

    /// §4.2 の `max(1, ATK - DEF / 2) × random(0.9 ... 1.1)`。
    ///
    /// `DEF / 2` は整数で割ると奇数のときに切り捨てられ、防御力が1点ぶん得をする。
    /// 実数で計算してから丸める。
    static func damage(
        atk: Int,
        def: Int,
        variance: ClosedRange<Double> = BalanceRules.damageVarianceRange,
        using generator: inout some RandomNumberGenerator
    ) -> Int {
        let base = max(1.0, Double(atk) - Double(def) / 2.0)
        let roll = Double.random(in: variance, using: &generator)
        return max(1, Int((base * roll).rounded()))
    }

    // MARK: - 組み立て

    /// プレイヤーの実効ステータスを組み立てる（§3.3 ＋ 装備）。
    static func playerFighter(level: Int, equipment: [Equipment], name: String = "主人公") -> Fighter {
        let bonus = equipment
            .filter(\.isEquipped)
            .reduce(into: (hp: 0, atk: 0, def: 0)) { total, item in
                let effective = item.effective
                total.hp += effective.hp
                total.atk += effective.atk
                total.def += effective.def
            }

        return Fighter(
            name: name,
            maxHP: BalanceRules.baseHP + level * BalanceRules.hpPerLevel + bonus.hp,
            atk: BalanceRules.baseATK + level * BalanceRules.atkPerLevel + bonus.atk,
            def: BalanceRules.baseDEF + level * BalanceRules.defPerLevel + bonus.def
        )
    }

    static func enemyFighter(_ enemy: MasterData.Enemy) -> Fighter {
        Fighter(name: enemy.name, maxHP: enemy.hp, atk: enemy.atk, def: enemy.def)
    }
}
