import Foundation

/// §17 の数表をコードにしたもの。
///
/// コード中に敵や装備の数値を直接書かないこと。バランス調整のたびに全体を触ることになる。
enum MasterData {

    // MARK: - 敵

    /// ダルモンの役割。ART_PROMPTS.md §3 のシルエット差と対応する（§17.2）。
    enum Role: String, Codable, CaseIterable {
        /// ダラリ型。標準。
        case standard
        /// ゴロネ型。硬いが手数が少ない。
        case tough
        /// ネムケ型。柔らかいが手数が多い。
        case swift
    }

    struct Enemy: Equatable {
        var id: String
        var name: String
        var hp: Int
        var atk: Int
        var def: Int
        var isBoss: Bool = false

        /// アセットカタログ上の画像名。未実装のボスなどでは `nil`。
        var assetName: String?

        var apCost: Int { isBoss ? BalanceRules.apCostBoss : BalanceRules.apCostNormal }
    }

    /// 個体の identity。ステータスは `Role` から、見た目と名前はここから決まる。
    ///
    /// **ステータスと identity を分けている理由**: §17.2 の設計式は役割ごとに1組しかないが、
    /// 図鑑としては12体を別個体として見せたい。同じ役割の個体が複数いても、
    /// 数値は式のまま、名前と絵だけが変わる。
    struct Species: Equatable {
        /// アセットカタログの画像名と一致させる。
        var id: String
        var name: String
        var role: Role
    }

    /// 各章に登場する4体（ART_PROMPTS.md §3.5）。
    static func species(chapter: Int) -> [Species] {
        switch chapter {
        case 1: return [
            Species(id: "darari", name: "ダラリ", role: .standard),
            Species(id: "nemuke", name: "ネムケ", role: .swift),
            Species(id: "gorone", name: "ゴロネ", role: .tough),
            Species(id: "akubi", name: "アクビ", role: .standard),
        ]
        case 2: return [
            Species(id: "uzukumari", name: "ウズクマリ", role: .standard),
            Species(id: "tadayoi", name: "タダヨイ", role: .swift),
            Species(id: "nebari", name: "ネバリ", role: .tough),
            Species(id: "motare", name: "モタレ", role: .standard),
        ]
        case 3: return [
            Species(id: "shizumi", name: "シズミ", role: .standard),
            Species(id: "kasumi", name: "カスミ", role: .swift),
            Species(id: "omori", name: "オモリ", role: .tough),
            Species(id: "nukegara", name: "ヌケガラ", role: .standard),
        ]
        default:
            assertionFailure("未定義の章 \(chapter)")
            return species(chapter: 3)
        }
    }

    /// 雑魚のステータス（§17.2）。
    ///
    /// 基準Lvは各章の中間地点。数値は次の式から出しており、
    /// テンポが合わない場合は §17.2 の係数（4ターン／25%）を変えて全体を引き直す。
    ///
    /// ```
    /// 雑魚HP  = 4 × (プレイヤーATK − 雑魚DEF / 2)
    /// 雑魚ATK = プレイヤーHP × 0.0625 + プレイヤーDEF / 2
    /// ```
    static func zako(chapter: Int, role: Role, species override: Species? = nil) -> Enemy {
        let stats: (hp: Int, atk: Int, def: Int)
        switch (chapter, role) {
        case (1, .standard): stats = (80, 12, 4)
        case (1, .tough):    stats = (68, 13, 10)
        case (1, .swift):    stats = (67, 15, 2)
        case (2, .standard): stats = (124, 19, 6)
        case (2, .tough):    stats = (104, 20, 16)
        case (2, .swift):    stats = (104, 23, 3)
        case (3, .standard): stats = (168, 25, 8)
        case (3, .tough):    stats = (144, 26, 20)
        case (3, .swift):    stats = (141, 29, 4)
        default:
            // 章の追加時に静かに壊れないよう、第3章の値で代替しつつ気付けるようにする。
            assertionFailure("未定義の章 \(chapter) / 役割 \(role)")
            stats = (168, 25, 8)
        }
        // 指定が無ければ、その章で同じ役割を持つ最初の個体を使う。
        let entry = override ?? species(chapter: chapter).first { $0.role == role }
        return Enemy(
            id: entry?.id ?? "zako_ch\(chapter)_\(role.rawValue)",
            name: entry?.name ?? role.rawValue,
            hp: stats.hp, atk: stats.atk, def: stats.def,
            assetName: entry?.id
        )
    }

    /// ボスのステータス（§17.3）。
    ///
    /// **HP は 1000回シミュレーションの結果で決めている（§17.12）。**
    /// 当初は期待値だけで 300 / 500 / 720 としていたが、実測すると装備を揃えた時点で
    /// 勝率100%になり「辛勝」になっていなかった。§4.2 の乱数（±10%）は10ターンかけると
    /// 平均に収束し、2ターン程度のマージンを覆せないため。
    ///
    /// それ以上に問題だったのは、**装備を揃えるだけで確定勝利なら §17.7 の強化に
    /// 存在意義が無くなる**こと。素材を集める理由が消え、活力パス（素材1.5倍）の
    /// 価値まで無意味になる。HP を上げ、強化に意味を持たせている。
    static func boss(chapter: Int) -> Enemy {
        let stats: (hp: Int, atk: Int, def: Int)
        switch chapter {
        case 1: stats = (370, 25, 10)
        case 2: stats = (570, 38, 16)
        case 3: stats = (890, 52, 22)
        default:
            assertionFailure("未定義の章 \(chapter)")
            stats = (720, 52, 22)
        }
        return Enemy(
            id: "boss_ch\(chapter)",
            name: bossName(chapter),
            hp: stats.hp, atk: stats.atk, def: stats.def,
            isBoss: true,
            assetName: bossAssetName(chapter)
        )
    }

    private static func bossName(_ chapter: Int) -> String {
        switch chapter {
        case 1: return "マドロミ"
        case 2: return "ムキリョク"
        case 3: return "ダルモン"
        default: return "ダルモン"
        }
    }

    /// ボスの立ち絵。`Assets.xcassets/Darumon/` の imageset 名と一致させる。
    /// アセットが無い間は `DarumonPortrait` が記号で代替するので、先に埋めておいてよい。
    private static func bossAssetName(_ chapter: Int) -> String {
        switch chapter {
        case 1: return "madoromi"
        case 2: return "mukiryoku"
        case 3: return "darumon"
        default: return "darumon"
        }
    }

    // MARK: - 地域（§17.9）

    /// 章に対応する地域。活気ゲージと「世界の記述」の入れ物。
    ///
    /// **`id` の文字列は保存データに入っている。** 変えると既存プレイヤーの活気が
    /// 別地域として作り直され、ゲージが 0 に戻る。名前は自由に変えてよい。
    struct Region: Equatable {
        var id: String
        var name: String
        var chapter: Int
        /// 背景アセット名。戦闘の背景と共用する。
        var assetName: String
    }

    static func region(chapter: Int) -> Region {
        switch chapter {
        case 1: return Region(id: regionId(1), name: "止まった住宅街", chapter: 1, assetName: "bg1")
        case 2: return Region(id: regionId(2), name: "灯りの落ちた商店街", chapter: 2, assetName: "bg2")
        case 3: return Region(id: regionId(3), name: "灰の窪地", chapter: 3, assetName: "bg3")
        default:
            assertionFailure("未定義の章 \(chapter)")
            return region(chapter: 3)
        }
    }

    static func regionId(_ chapter: Int) -> String { "region_ch\(chapter)" }

    // MARK: - 章とノード

    /// 章の解放に必要な累計歩数（§5.1）。1日あたりの歩数が変わっても到達Lvは変わらない。
    static func chapterGate(_ chapter: Int) -> Int {
        switch chapter {
        case 1: return 20_000
        case 2: return 60_000
        case 3: return 120_000
        default: return .max
        }
    }

    static let nodesPerChapter = 8

    /// ノードの中身（§17.4）。
    ///
    /// ノード2/4/6 では装備を確定ドロップさせる。素材から作らせると、
    /// 運の悪いプレイヤーが §4.4 の「装備ありで辛勝」に到達できない。
    static func node(chapter: Int, index: Int) -> (enemy: Enemy, equipmentReward: Equipment?) {
        let roster = species(chapter: chapter)
        // 同じ章の4体を satisfying に配る。ノード5と7で後半の2体を出すことで、
        // 章の途中で「新しいダルモンが出た」という変化を作る。
        func enemy(_ position: Int) -> Enemy {
            let entry = roster[min(position, roster.count - 1)]
            return zako(chapter: chapter, role: entry.role, species: entry)
        }

        switch index {
        case 1:
            return (enemy(0), nil)
        case 3:
            return (enemy(1), nil)
        case 5:
            return (enemy(3), nil)
        case 7:
            return (enemy(1), nil)
        case 2:
            return (enemy(2), equipment(chapter: chapter, slot: .weapon))
        case 4:
            return (enemy(2), equipment(chapter: chapter, slot: .armor))
        case 6:
            return (enemy(2), equipment(chapter: chapter, slot: .accessory))
        case 8:
            return (boss(chapter: chapter), nil)
        default:
            assertionFailure("ノード番号は 1...\(nodesPerChapter)。受け取った値: \(index)")
            return (zako(chapter: chapter, role: .standard), nil)
        }
    }

    // MARK: - 装備

    /// 装備カタログ（§17.6）。
    ///
    /// **各章の合計値が §17.3 の検証前提と一致していること。**
    /// 第1章の合計は §4.4 の「装備あり Lv6 = HP160 / ATK38 / DEF22」と厳密に一致する。
    static func equipment(chapter: Int, slot: EquipmentSlot) -> Equipment {
        let stats: (hp: Int, atk: Int, def: Int)
        switch (chapter, slot) {
        case (1, .weapon):    stats = (0, 7, 0)
        case (1, .armor):     stats = (50, 0, 3)
        case (1, .accessory): stats = (0, 3, 2)
        case (2, .weapon):    stats = (0, 13, 0)
        case (2, .armor):     stats = (90, 0, 6)
        case (2, .accessory): stats = (0, 5, 3)
        case (3, .weapon):    stats = (0, 20, 0)
        case (3, .armor):     stats = (140, 0, 9)
        case (3, .accessory): stats = (0, 8, 5)
        default:
            assertionFailure("未定義の章 \(chapter) / スロット \(slot)")
            stats = (0, 0, 0)
        }
        return Equipment(
            id: "eq_ch\(chapter)_\(slot.rawValue)",
            name: equipmentName(chapter: chapter, slot: slot),
            slot: slot,
            hp: stats.hp, atk: stats.atk, def: stats.def
        )
    }

    private static func equipmentName(chapter: Int, slot: EquipmentSlot) -> String {
        let tier = ["", "目覚めの", "抗いの", "灯火の"][min(chapter, 3)]
        switch slot {
        case .weapon:    return "\(tier)杖"
        case .armor:     return "\(tier)外套"
        case .accessory: return "\(tier)護符"
        }
    }

    /// 指定した章までの装備を全て揃えた場合の合計値。バランス検証で使う。
    static func fullSetBonus(chapter: Int) -> (hp: Int, atk: Int, def: Int) {
        EquipmentSlot.allCases.reduce(into: (hp: 0, atk: 0, def: 0)) { total, slot in
            let item = equipment(chapter: chapter, slot: slot)
            total.hp += item.hp
            total.atk += item.atk
            total.def += item.def
        }
    }
}
