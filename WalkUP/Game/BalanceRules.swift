import Foundation

/// §3 / §17 / §18 の数値を1箇所に集約したもの。
///
/// **マジックナンバーをロジックに散らさないこと。** バランス調整はここだけを触れば済む状態を保つ。
/// 各定数には必ず出典の節番号を書く。根拠を失った数値は調整できなくなる。
enum BalanceRules {

    // MARK: - 歩数の変換（§3.1）

    /// 1日に加算できる歩数の上限。チート対策（§3.1）。
    static let dailyStepCap = 30_000

    /// 1 AP に必要な歩数（§3.1）。
    static let stepsPerAP = 1_000

    // MARK: - レベル（§3.2 / §3.3）

    /// `Lv N に必要な累計EXP = expPerLevelSquared × N²`（§3.2）。
    static let expPerLevelSquared = 500

    static let baseHP = 50
    static let baseATK = 10
    static let baseDEF = 5
    static let hpPerLevel = 10
    static let atkPerLevel = 3
    static let defPerLevel = 2

    // MARK: - 戦闘（§4.2）

    /// ダメージの乱数幅（§4.2 改訂）。
    ///
    /// **当初の仕様は ±10%（0.9〜1.1）だったが、シミュレーションで実用に耐えないと判明した。**
    /// 10ターン以上かかる戦闘では ±10% の振れが平均に収束し、勝敗が実質的に決定論になる。
    /// ボスHPを20動かすだけで勝率が68ポイント飛ぶため、調整そのものが成立しなかった。
    /// ±20% にすると同じ変化幅での落差が40ポイントに収まり、調整可能な曲線になる（§17.12）。
    static let damageVarianceRange: ClosedRange<Double> = 0.8...1.2

    /// 決着がつかない場合に敗北扱いとするターン数（§4.2）。
    static let maxTurns = 30

    // MARK: - AP 消費（§17.1）

    static let apCostNormal = 1
    static let apCostBoss = 3

    // MARK: - 強化（§17.7）

    /// 強化1段階あたりの上昇率。基礎値に対する割合（§17.7）。
    static let enhanceGainPerLevel = 0.20

    static let maxEnhanceLevel = 5

    /// 強化に必要な澱 `5 × (enhanceLevel + 1)²`（§17.7）。
    static func enhanceCost(currentLevel: Int) -> Int {
        5 * (currentLevel + 1) * (currentLevel + 1)
    }

    // MARK: - ドロップ（§17.8）

    static let dregsFromNormal = 3
    static let dregsFromBoss = 10
    static let coreFromBoss = 1

    /// 活力パス適用時の素材・活気の倍率（§17.10）。
    static let passMultiplier = 1.5

    /// 敗北時に持ち帰れる割合（§4.3 / §17.8）。切り上げ。
    static let defeatSalvageRatio = 1.0 / 3.0

    // MARK: - 活気ゲージ（§17.9）

    static let vitalityFromNormal = 2
    static let vitalityFromBoss = 10
    static let vitalityMax = 100

    // MARK: - 道標（§18.3）

    /// 道標1つに必要な歩数（§18.3）。
    static let stepsPerMilestone = 500

    /// 道標の日次上限。これが無いと30,000歩の日に60個出て経済が壊れる（§18.3）。
    static let milestoneDailyCap = 12

    /// 核のかけら何個で核1つになるか（§18.4）。
    static let coreShardsPerCore = 10

    // MARK: - 導出

    /// パス適用後の数量。切り上げ（§17.8）。
    static func applyPass(_ amount: Int, hasPass: Bool) -> Int {
        guard hasPass else { return amount }
        return Int((Double(amount) * passMultiplier).rounded(.up))
    }

    /// 敗北時の持ち帰り量。切り上げ（§17.8）。
    static func salvaged(_ amount: Int) -> Int {
        Int((Double(amount) * defeatSalvageRatio).rounded(.up))
    }
}
