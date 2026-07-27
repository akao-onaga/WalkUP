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

// MARK: - 旧データの移行

extension GameState {
    /// 図鑑の ID を役割ベース（`zako_ch1_standard`）から種別ベース（`darari`）へ寄せる。
    ///
    /// **12体を実装する前のビルドは役割ごとに1件しか記録していなかった**（`zako()` の
    /// 個体指定が無かった頃の `id`）。そのまま読むと、討伐済みのダルモンが図鑑で
    /// 「未発見」に戻る。TestFlight 0.1.0 を入れている人に実際に起きる。
    ///
    /// 付け替え先は `zako()` の既定と同じ規則——その章で同じ役割を持つ最初の個体——にする。
    /// 当時その役割で戦った相手は必ずその個体だったため、これが唯一の正しい対応付け。
    ///
    /// **`schemaVersion` は上げない。** 移行後も形式は変わらず、古いビルドで読んでも
    /// 壊れない（見覚えのない ID として無視されるだけ）。上げると読み込み自体を
    /// 拒否させることになり、失うものの方が大きい。
    func migratingLegacyBestiaryIDs() -> GameState {
        var migrated = self
        var merged: [BestiaryEntry] = []

        for entry in bestiary {
            let id = Self.modernBestiaryID(entry.darumonId)
            if let index = merged.firstIndex(where: { $0.darumonId == id }) {
                merged[index].defeatedCount += entry.defeatedCount
                merged[index].isSighted = merged[index].isSighted || entry.isSighted
                merged[index].firstSeenAt = [merged[index].firstSeenAt, entry.firstSeenAt]
                    .compactMap { $0 }.min()
            } else {
                var moved = entry
                moved.darumonId = id
                merged.append(moved)
            }
        }

        migrated.bestiary = merged
        return migrated
    }

    /// 装備の表示名をマスターデータから引き直す。
    ///
    /// **`Equipment.name` は保存データに焼き付いている。** 入手した時点の名前が
    /// そのまま残るので、`equipmentName()` を変えても既に持っている装備には効かない。
    /// 武器を「杖」から「靴」に変えたとき（§1 の設計原理に合わせた）、
    /// 既存プレイヤーの持ち物だけ「目覚めの杖」のまま残る状態になった。
    ///
    /// 名前は完全にマスターデータから導けるので、読み込みのたびに引き直せば済む。
    /// 強化段階や装備状態には触らない。
    func refreshingEquipmentNames() -> GameState {
        var migrated = self
        for index in migrated.equipment.indices {
            let item = migrated.equipment[index]
            guard let source = Self.masterEquipment(id: item.id) else { continue }
            migrated.equipment[index].name = source.name
        }
        return migrated
    }

    /// `eq_ch{章}_{スロット}` からマスターデータの装備を引く。形式が合わなければ nil。
    private static func masterEquipment(id: String) -> Equipment? {
        let parts = id.split(separator: "_")
        guard parts.count == 3, parts[0] == "eq",
              let chapter = Int(parts[1].dropFirst(2)),
              let slot = EquipmentSlot(rawValue: String(parts[2]))
        else { return nil }
        return MasterData.equipment(chapter: chapter, slot: slot)
    }

    /// `zako_ch{章}_{役割}` を、その章で同じ役割を持つ最初の個体の ID に読み替える。
    /// 形式が合わなければそのまま返す（既に種別ベース、またはボス）。
    private static func modernBestiaryID(_ id: String) -> String {
        let parts = id.split(separator: "_")
        guard parts.count == 3, parts[0] == "zako",
              let chapter = Int(parts[1].dropFirst(2)),
              let role = MasterData.Role(rawValue: String(parts[2])),
              let species = MasterData.species(chapter: chapter).first(where: { $0.role == role })
        else { return id }
        return species.id
    }
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

// MARK: - 素材の識別子

enum MaterialID {
    /// 怠惰の澱。全ダルモンがドロップし、装備強化に使う（§17.5）。
    static let dregs = "dregs"
    /// 怠惰の核。ボスのみ、および道標のかけら10個から（§17.5 / §18.4）。
    static let core = "core"
    /// 核のかけら。10個で核1つ（§18.4）。
    static let coreShard = "core_shard"
}
