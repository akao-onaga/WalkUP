import SwiftUI

/// 図鑑（画面 #8）。
///
/// **記録は既に溜まっている。** 目撃は道標（§18.4）、討伐は戦闘結果から
/// `GameState.bestiary` に入っており、この画面はそれを読むだけで書き込まない。
///
/// 3つの状態を見せる（§18.4）。
/// - 未発見: 名前も姿も出さない
/// - 目撃のみ: 影だけ見せる。「まだ会っていないダルモンがいる」ことを伝える
/// - 討伐済み: 絵・名前・討伐数・初めて見た日
struct BestiaryView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    /// 開いている詳細。未発見の個体は開けないので、ここには入らない。
    @State private var detail: Detail?

    struct Detail: Identifiable {
        let chapter: Int
        let enemy: MasterData.Enemy
        var id: String { enemy.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(title: "図鑑", onClose: { dismiss() })

            ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    ForEach(1...3, id: \.self) { chapter in
                        chapterSection(chapter)
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $detail) { item in
            BestiaryDetailView(
                chapter: item.chapter,
                enemy: item.enemy,
                entry: game.bestiaryEntry(id: item.enemy.id)
            )
        }
    }

    // MARK: - 集計

    /// 図鑑に載る全個体。雑魚4体＋ボス1体を章の順に並べる。
    private var roster: [(chapter: Int, enemy: MasterData.Enemy)] {
        (1...3).flatMap { chapter in
            MasterData.species(chapter: chapter).map { species in
                (chapter, MasterData.zako(chapter: chapter, role: species.role, species: species))
            } + [(chapter, MasterData.boss(chapter: chapter))]
        }
    }

    private var defeatedCount: Int {
        roster.filter { (game.bestiaryEntry(id: $0.enemy.id)?.defeatedCount ?? 0) > 0 }.count
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(defeatedCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                Text("/ \(roster.count) 体")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            MeterBar(value: Double(defeatedCount) / Double(roster.count), tint: Theme.accent)
            Text("討伐すると図鑑に載る。道標で目撃したダルモンは影だけが残る。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
                .panel()
    }

    // MARK: - 章

    private func chapterSection(_ chapter: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(MasterData.region(chapter: chapter).name).font(.headline)
                Spacer()
                Text("第\(chapter)章").font(.caption).foregroundStyle(.secondary)
            }

            ForEach(roster.filter { $0.chapter == chapter }, id: \.enemy.id) { item in
                let known = game.bestiaryEntry(id: item.enemy.id)?.isSighted ?? false
                Button {
                    detail = Detail(chapter: item.chapter, enemy: item.enemy)
                } label: {
                    row(item.enemy)
                        // 行の余白も押せるようにする（§15 の落とし穴）。
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // 未発見は開いても何も無いので閉じる。
                .disabled(!known)
            }
        }
        .panel()
    }

    private func row(_ enemy: MasterData.Enemy) -> some View {
        let entry = game.bestiaryEntry(id: enemy.id)
        let defeated = (entry?.defeatedCount ?? 0) > 0
        let sighted = entry?.isSighted ?? false

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(defeated ? Theme.accent.opacity(0.22) : Color.gray.opacity(0.12))
                    .frame(width: 52, height: 52)

                if defeated {
                    DarumonPortrait(enemy: enemy).frame(width: 46, height: 46)
                } else if sighted {
                    // 影。輪郭だけを見せて正体は伏せる。
                    DarumonPortrait(enemy: enemy)
                        .frame(width: 46, height: 46)
                        .brightness(-1)
                        .opacity(0.45)
                } else {
                    Image(systemName: "questionmark")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(title(for: enemy, defeated: defeated, sighted: sighted))
                    .font(.subheadline.weight(enemy.isBoss ? .bold : .regular))
                    .foregroundStyle(defeated || sighted ? .primary : .secondary)

                if defeated {
                    Text(detail(enemy: enemy, entry: entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if sighted {
                    Text("目撃の記録のみ。討伐すると正体が分かる")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if defeated, let count = entry?.defeatedCount {
                Text("×\(count)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private func title(for enemy: MasterData.Enemy, defeated: Bool, sighted: Bool) -> String {
        if defeated { return enemy.isBoss ? "ボス：\(enemy.name)" : enemy.name }
        if sighted { return enemy.isBoss ? "ボス：？？？" : "？？？" }
        return "未発見"
    }

    private func detail(enemy: MasterData.Enemy, entry: BestiaryEntry?) -> String {
        var parts = ["HP \(enemy.hp) / 攻 \(enemy.atk) / 守 \(enemy.def)"]
        if let date = entry?.firstSeenAt {
            parts.append(date.formatted(date: .numeric, time: .omitted))
        }
        return parts.joined(separator: "  ・  ")
    }
}
