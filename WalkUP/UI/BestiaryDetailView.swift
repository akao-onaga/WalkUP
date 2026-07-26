import SwiftUI

/// 図鑑の詳細（画面 #8 の下層）。
///
/// 一覧を拡大しただけの画面にしないため、**解説文（`MasterData.flavor`）を本体に据える。**
/// 数値は添え物で、ここに来る動機は「どんな相手だったのか」を読むことにある。
///
/// 目撃のみ（影）の個体でも開ける。**名前と解説は伏せる**が、
/// 「まだ会っていない相手がいる」という手触りは残す（§18.4）。
struct BestiaryDetailView: View {
    let chapter: Int
    let enemy: MasterData.Enemy
    let entry: BestiaryEntry?

    @Environment(\.dismiss) private var dismiss

    private var defeated: Bool { (entry?.defeatedCount ?? 0) > 0 }

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(title: defeated ? enemy.name : "？？？", onClose: { dismiss() }) {
                if defeated, let count = entry?.defeatedCount {
                    HeaderCounter(systemImage: "checkmark.seal.fill", value: count)
                }
            }

            ScrollView {
                VStack(spacing: 18) {
                    portrait
                    flavorCard
                    statsCard
                }
                .padding(16)
            }
        }
        .background(backdrop.ignoresSafeArea())
    }

    /// 立ち絵。**その個体が住む地域を背に置く。** 白地に浮かせると標本になってしまう。
    private var portrait: some View {
        ZStack {
            DarumonPortrait(enemy: enemy)
                .frame(maxWidth: 240, maxHeight: 240)
                // 影の個体は輪郭だけ。討伐すると色が戻る。
                .brightness(defeated ? 0 : -1)
                .opacity(defeated ? 1 : 0.5)
                .modifier(IdleBob(active: true))
                .shadow(color: Theme.ink.opacity(0.35), radius: 0, y: 4)
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
    }

    private var flavorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: defeated ? "記録" : "目撃の記録のみ")

            Text(defeated
                 ? MasterData.flavor(for: enemy.id)
                 : "影だけが記録されている。討伐すれば、正体と記録が明らかになる。")
                .font(.callout)
                .foregroundStyle(defeated ? Theme.text : Theme.textSoft)
                .fixedSize(horizontal: false, vertical: true)

            if let date = entry?.firstSeenAt {
                Text("初めて見た日　\(date.formatted(date: .long, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "能力")

            HStack(spacing: 12) {
                StatTile(title: "HP", count: defeated ? enemy.hp : 0,
                         systemImage: "heart.fill")
                StatTile(title: "攻", count: defeated ? enemy.atk : 0,
                         systemImage: "flame.fill", tint: Theme.vigor)
                StatTile(title: "守", count: defeated ? enemy.def : 0,
                         systemImage: "shield.fill")
            }
            // 未討伐は数値を伏せる。並びだけ見せて「埋まっていない」ことを示す。
            .opacity(defeated ? 1 : 0.35)

            HStack {
                Text(MasterData.region(chapter: chapter).name)
                    .font(.caption)
                    .foregroundStyle(Theme.textSoft)
                Spacer()
                Text("第\(chapter)章")
                    .font(.caption)
                    .foregroundStyle(Theme.textSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    private var backdrop: some View {
        ZStack {
            Theme.background

            if UIImage(named: MasterData.region(chapter: chapter).assetName) != nil {
                Image(MasterData.region(chapter: chapter).assetName)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.5)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Theme.background.opacity(0.2),
                                Theme.background.opacity(0.9),
                                Theme.background
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
        }
    }
}
