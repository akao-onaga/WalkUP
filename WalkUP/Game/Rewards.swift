import Foundation

/// 戦闘報酬の計算（§17.8 / §17.9）。純粋関数として持つことでテストできる。
enum RewardCalculator {

    struct Reward: Equatable {
        var dregs = 0
        var cores = 0
        var vitality = 0
        /// ノード報酬の装備（§17.4 のノード2/4/6）。勝利時のみ。
        var equipment: Equipment?

        var isEmpty: Bool {
            dregs == 0 && cores == 0 && vitality == 0 && equipment == nil
        }
    }

    /// 戦闘1回の報酬。
    ///
    /// - Parameter hasPass: 活力パスの有無。素材と活気に 1.5倍が乗る（§17.10）。
    ///   **EXP・AP・歩数には決して乗せないこと**（§2 の絶対ルール2）。
    static func forBattle(
        enemy: MasterData.Enemy,
        result: BattleEngine.Result,
        hasPass: Bool,
        equipmentReward: Equipment?
    ) -> Reward {
        let baseDregs = enemy.isBoss ? BalanceRules.dregsFromBoss : BalanceRules.dregsFromNormal
        let baseVitality = enemy.isBoss ? BalanceRules.vitalityFromBoss : BalanceRules.vitalityFromNormal

        switch result {
        case .victory:
            return Reward(
                dregs: BalanceRules.applyPass(baseDregs, hasPass: hasPass),
                cores: enemy.isBoss ? BalanceRules.coreFromBoss : 0,
                vitality: BalanceRules.applyPass(baseVitality, hasPass: hasPass),
                equipment: equipmentReward
            )

        case .defeat:
            // §4.3「全損させない。素材の一部は持ち帰れる」。
            // 消費した AP は返らない。装備も手に入らない。
            return Reward(
                dregs: BalanceRules.applyPass(BalanceRules.salvaged(baseDregs), hasPass: hasPass),
                cores: 0,
                vitality: 0,
                equipment: nil
            )
        }
    }
}

/// 道標の開封（§18.4）。
enum MilestoneOpener {

    enum Find: Equatable, Identifiable {
        /// 世界の記述。
        case lore(id: String, text: String)
        /// ダルモンの目撃。図鑑に影として載る。
        case sighting(darumonId: String, name: String)
        /// 核のかけら。
        case coreShard

        var id: String {
            switch self {
            case .lore(let id, _): return "lore-\(id)"
            case .sighting(let id, _): return "sight-\(id)"
            case .coreShard: return "shard-\(UUID().uuidString)"
            }
        }

        var title: String {
            switch self {
            case .lore: return "世界の記述"
            case .sighting(_, let name): return "\(name) の目撃情報"
            case .coreShard: return "怠惰の核のかけら"
            }
        }

        var icon: String {
            switch self {
            case .lore: return "book.closed"
            case .sighting: return "eye"
            case .coreShard: return "diamond"
            }
        }
    }

    /// §18.4 の抽選表。合計100。
    ///
    /// **携行品は廃止した（2026-07-27）。** 戦闘は毎回全快で始まる設計（§4.1）なので、
    /// 「戦闘前に使える回復」は効果量をいくつにしても何も起きない。
    /// 一時強化に読み替える手もあったが、道具の管理という層を1つ増やすだけで、
    /// §2 の「1セッション3分」に対して割に合わない。
    private static let weights: [(kind: Int, weight: Int)] = [
        (0, 65),  // 世界の記述
        (1, 10),  // 目撃情報
        (2, 25),  // 核のかけら
    ]

    /// 道標を `count` 個まとめて開封する。
    ///
    /// **一括開封にすること**（§18.2）。1つずつ開けさせると §2 の「1セッション3分」が壊れる。
    ///
    /// - Parameter alreadySighted: 目撃済み・討伐済みのダルモンID。
    ///   **未発見の個体からしか引かない**ため必要。既に見た相手を引いても図鑑は動かず、
    ///   開封の演出だけが1枚増える。
    static func open(
        count: Int,
        unlockedChapter: Int,
        alreadyUnlockedLore: Set<String>,
        alreadySighted: Set<String>,
        using generator: inout some RandomNumberGenerator
    ) -> [Find] {
        guard count > 0 else { return [] }
        var finds: [Find] = []
        var usedLore = alreadyUnlockedLore
        var sighted = alreadySighted

        // 既に解放済みのものを引いたら、次の未解放へ回す（§18.6）。
        func takeLore() -> Find? {
            guard let entry = LoreCatalog.nextUnlocked(excluding: usedLore, chapter: unlockedChapter)
            else { return nil }
            usedLore.insert(entry.id)
            return .lore(id: entry.id, text: entry.text)
        }

        // 開放済みの章すべてが対象（同じ役割が2体いる章でも、4体とも出る）。
        func takeSighting() -> Find? {
            var pool: [MasterData.Enemy] = []
            for chapter in 1...max(1, unlockedChapter) {
                for species in MasterData.species(chapter: chapter) where !sighted.contains(species.id) {
                    pool.append(MasterData.zako(chapter: chapter, role: species.role, species: species))
                }
            }
            guard let enemy = pool.randomElement(using: &generator) else { return nil }
            sighted.insert(enemy.id)
            return .sighting(darumonId: enemy.id, name: enemy.name)
        }

        // 引き切った時の逃がし先は**もう一方の読み物側**にする。
        // かけらへ直行させると、記述22本を読み終えた数日後から核が跳ね上がり、
        // §18.4 の「核1つに約3.3日」という補助経路の前提が崩れる。
        for _ in 0..<count {
            switch pick(using: &generator) {
            case 0: finds.append(takeLore() ?? takeSighting() ?? .coreShard)
            case 1: finds.append(takeSighting() ?? takeLore() ?? .coreShard)
            default: finds.append(.coreShard)
            }
        }
        return finds
    }

    private static func pick(using generator: inout some RandomNumberGenerator) -> Int {
        let total = weights.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<total, using: &generator)
        for entry in weights {
            roll -= entry.weight
            if roll < 0 { return entry.kind }
        }
        return weights[0].kind
    }
}

/// 「世界の記述」の文面（§18.4）。
///
/// アートもデータモデルも要らず、テキストだけで作れる。
/// §1 のコンセプト（世界は怠惰に堕ち、歩数だけがそれを打ち破る資源）と一致しており、
/// **章が進まない日でも世界は取り戻されていく**という体験を作る。
enum LoreCatalog {
    struct Entry {
        let id: String
        let chapter: Int
        let text: String
    }

    static let all: [Entry] = [
        .init(id: "lore_001", chapter: 1, text: "はじめに止まったのは、街の時計だった。誰も直そうとしなかった。"),
        .init(id: "lore_002", chapter: 1, text: "郵便受けに手紙が溜まっている。中身は、どれも読まれるのを諦めている。"),
        .init(id: "lore_003", chapter: 1, text: "パン屋の主人は、生地をこねる手を止めて眠っている。もう三日になる。"),
        .init(id: "lore_004", chapter: 1, text: "子どもたちの走る音が消えた通りに、風だけが残った。"),
        .init(id: "lore_005", chapter: 1, text: "ダルモンは襲わない。ただ、そばにいるだけで人から気力を抜いていく。"),
        .init(id: "lore_006", chapter: 1, text: "歩くと、足の裏に地面の硬さが返ってくる。それだけで少し目が覚める。"),
        .init(id: "lore_007", chapter: 1, text: "誰かの足跡が残っていた。あなたのものではない。まだ歩いている人がいる。"),
        .init(id: "lore_008", chapter: 1, text: "駅の改札は開いたままだ。通り抜ける人がいないので、閉じる意味がない。"),
        .init(id: "lore_009", chapter: 1, text: "自販機の灯りだけが律儀に点いている。誰も買わないまま、温かい缶が冷めていく。"),
        .init(id: "lore_010", chapter: 1, text: "図書館の本は、開かれた頁のまま埃をかぶっている。続きを読む者がいない。"),
        .init(id: "lore_011", chapter: 1, text: "橋の上で立ち止まると、川はまだ流れていた。動くものが、少し羨ましい。"),
        .init(id: "lore_012", chapter: 1, text: "「明日でいい」という言葉が、この街でいちばんよく使われている。"),
        .init(id: "lore_013", chapter: 2, text: "隣町へ続く道は、草に覆われかけていた。往来が絶えると、道は自然に還る。"),
        .init(id: "lore_014", chapter: 2, text: "商店街の半分はシャッターが下りている。残り半分も、開ける理由を探している。"),
        .init(id: "lore_015", chapter: 2, text: "壊れた自転車が置き去りにされている。直せば動く。直す気力が無いだけだ。"),
        .init(id: "lore_016", chapter: 2, text: "誰かが壁に線を引いていた。歩いた日を数えた跡らしい。途中で途切れている。"),
        .init(id: "lore_017", chapter: 2, text: "ダルモンの通った跡には、いつも眠気に似た匂いが残る。"),
        .init(id: "lore_018", chapter: 2, text: "老人が縁側で言った。「昔はな、みんな歩いて隣町まで行ったんだ」"),
        .init(id: "lore_019", chapter: 3, text: "世界の中心に近づくほど、空気が重くなる。息をするのも億劫になる。"),
        .init(id: "lore_020", chapter: 3, text: "ここでは誰も歩かない。歩くという発想そのものが失われている。"),
        .init(id: "lore_021", chapter: 3, text: "怠惰は罰ではない。ただ、そこに留まり続けることが、静かに全部を奪っていく。"),
        .init(id: "lore_022", chapter: 3, text: "あなたの足音が響く。この場所で音を立てているのは、あなただけだ。"),
    ]

    /// まだ解放していない記述のうち、最も若いものを返す。
    ///
    /// 重複を引いた場合の振り替え先。順に埋まるので「読み物として途中が抜ける」ことがない。
    static func nextUnlocked(excluding used: Set<String>, chapter: Int) -> Entry? {
        all.first { $0.chapter <= max(1, chapter) && !used.contains($0.id) }
    }

    static func text(for id: String) -> String? {
        all.first { $0.id == id }?.text
    }
}
