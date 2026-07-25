import Foundation

/// ゲームの全状態。これ1つを JSON として丸ごと保存する（§8 / §15-1）。
///
/// 値型で持つことで、変換や戦闘を純粋関数として書ける。テストが容易になる。
struct GameState: Codable, Equatable {
    /// 保存形式のバージョン。フィールドを削除・意味変更する際に上げる。
    var schemaVersion: Int = 1

    var player: PlayerState = PlayerState()
    var equipment: [Equipment] = []
    var chapters: [ChapterProgress] = []
    var regions: [RegionState] = []
    var bestiary: [BestiaryEntry] = []

    /// 素材ID → 所持数（§17.5）。`MaterialID` を参照。
    var materials: [String: Int] = [:]

    /// 携行品ID → 所持数（§18.5）。
    var consumables: [String: Int] = [:]

    /// 解放済みの「世界の記述」ID（§18.4）。
    var unlockedLore: [String] = []

    /// 未開封の道標の数（§18.3）。
    ///
    /// 保存する必要がある。付与は歩数の処理時に起きるが、開封はプレイヤーの操作なので、
    /// アプリを閉じてから開くまでの間を跨いで持ち越さなければならない。
    var pendingMilestones: Int = 0
}

// MARK: - プレイヤー

/// プレイヤーの状態。
///
/// **`exp` と `level` は保存しない。** §8 では両方を保持する設計だったが、
/// `exp` は §3.1 より常に `cumulativeSteps` と等しく、`level` は §3.2 より `exp` の関数。
/// 保存すると三者が食い違いうるため、`cumulativeSteps` だけを真実の源として計算で導く。
///
/// この等式が崩れるのは EXP のボーナス源ができた場合だが、§17.10 で
/// 活力パスは EXP に影響しないと確定しているため、現時点でボーナス源は存在しない。
struct PlayerState: Codable, Equatable {
    /// 上限適用後の累計歩数。EXP・レベル・章ゲートすべての基準。
    var cumulativeSteps: Int = 0

    /// 活力（AP）の残高。討伐で消費する（§17.1）。
    var ap: Int = 0

    /// 最後に歩数を処理した時刻。`nil` は初回未処理（§3.4）。
    var lastProcessedDate: Date?

    /// 当日分として既に加算した歩数（§3.4）。日付が変わると 0 に戻る。
    var todayCreditedSteps: Int = 0

    /// 当日分として既に付与した道標の数（§18.5）。日付が変わると 0 に戻る。
    var milestoneCreditedToday: Int = 0

    /// 経験値。§3.1 より 1歩 = 1 EXP。
    var exp: Int { cumulativeSteps }

    /// レベル。§3.2 の `Lv N に必要な累計EXP = 500 × N²` を逆に解いたもの。
    /// EXP 0 でも Lv1 として扱う。
    var level: Int {
        max(1, Int((Double(exp) / 500).squareRoot()))
    }
}

// MARK: - 装備

enum EquipmentSlot: String, Codable, CaseIterable {
    case weapon
    case armor
    case accessory
}

struct Equipment: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var slot: EquipmentSlot
    var hp: Int
    var atk: Int
    var def: Int

    /// 強化段階 0〜5（§17.7）。
    var enhanceLevel: Int = 0

    var isEquipped: Bool = false

    /// 強化を反映した実効値。§17.7 より `基礎値 × (1 + 0.20 × enhanceLevel)`。
    var effective: (hp: Int, atk: Int, def: Int) {
        let multiplier = 1.0 + BalanceRules.enhanceGainPerLevel * Double(enhanceLevel)
        return (
            hp: Int(Double(hp) * multiplier),
            atk: Int(Double(atk) * multiplier),
            def: Int(Double(def) * multiplier)
        )
    }
}

// MARK: - 進行

struct ChapterProgress: Codable, Equatable {
    var chapterId: Int
    var nodeIndex: Int = 0
    var isCleared: Bool = false
}

struct RegionState: Codable, Equatable {
    var regionId: String
    /// 活気ゲージ 0...100（§17.9）。
    var vitality: Int = 0
    var isUnlocked: Bool = false
}

/// 図鑑の1件。
///
/// §18.4 の「目撃情報」に対応するため、**目撃済みだが未討伐**の状態を表現できる必要がある。
/// `defeatedCount == 0 && isSighted` が「影」の状態。
struct BestiaryEntry: Codable, Equatable {
    var darumonId: String
    var defeatedCount: Int = 0
    var isSighted: Bool = false
    var firstSeenAt: Date?

    /// 図鑑に影として出るが、正体は伏せられている状態。
    var isShadowOnly: Bool { isSighted && defeatedCount == 0 }
}

// MARK: - 素材・携行品の識別子

enum MaterialID {
    /// 怠惰の澱。全ダルモンがドロップし、装備強化に使う（§17.5）。
    static let dregs = "dregs"
    /// 怠惰の核。ボスのみ、および道標のかけら10個から（§17.5 / §18.4）。
    static let core = "core"
    /// 核のかけら。10個で核1つ（§18.4）。
    static let coreShard = "core_shard"
}
