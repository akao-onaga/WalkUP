import SwiftUI

/// 地域／復興（画面 #7）。
///
/// 活気ゲージ（§17.9）と「世界の記述」（§18.4）をまとめて見せる場所。
/// **どちらも既に溜まっているデータで、この画面は読むだけ。**
///
/// §1 のコンセプト（歩いた分だけ世界が戻ってくる）が目に見えるのはここだけなので、
/// 章が進まない日でも開く価値がある画面にしている。
struct RegionView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(1...3, id: \.self) { chapter in
                        regionCard(chapter)
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("地域")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func regionCard(_ chapter: Int) -> some View {
        let region = MasterData.region(chapter: chapter)
        let isOpen = game.player.cumulativeSteps >= MasterData.chapterGate(chapter)
        let vitality = game.regionState(chapter: chapter).vitality

        return VStack(alignment: .leading, spacing: 0) {
            header(region: region, isOpen: isOpen)

            VStack(alignment: .leading, spacing: 14) {
                if isOpen {
                    vitalitySection(vitality)
                    loreSection(chapter)
                } else {
                    Label("\(MasterData.chapterGate(chapter).formatted()) 歩で解放", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.card)
                .shadow(color: Theme.ink.opacity(0.22), radius: 0, y: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth)
        )
    }

    // MARK: - 見出し

    /// 背景画を敷いた見出し。
    ///
    /// **文字は `.white` で固定する。** 背景を画像で固定した以上、`.primary` は
    /// ライトモードで黒くなって沈む（§15-9 で2度踏んだ落とし穴）。
    private func header(region: MasterData.Region, isOpen: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            if UIImage(named: region.assetName) != nil {
                Image(region.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 110)
                    .clipped()
                    .saturation(isOpen ? 1 : 0)
            } else {
                Theme.accent.opacity(0.25).frame(height: 110)
            }

            LinearGradient(
                colors: [.black.opacity(0.15), .black.opacity(0.65)],
                startPoint: .top, endPoint: .bottom
            )

            HStack(spacing: 6) {
                if !isOpen {
                    Image(systemName: "lock.fill").font(.caption)
                }
                Text(isOpen ? region.name : "？？？")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 3)
            .padding(14)
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 活気

    private func vitalitySection(_ vitality: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("活気").font(.subheadline.bold())
                Spacer()
                Text("\(vitality) / \(BalanceRules.vitalityMax)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            }
            MeterBar(value: Double(vitality) / Double(BalanceRules.vitalityMax), tint: Theme.vigor)
            Text(vitality >= BalanceRules.vitalityMax
                 ? "この地域は活気を取り戻した。"
                 : "ダルモンを討伐するほど、街に人の気配が戻る。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 世界の記述

    @ViewBuilder
    private func loreSection(_ chapter: Int) -> some View {
        let entries = game.lore(chapter: chapter)
        let unlocked = entries.filter(\.isUnlocked).count

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("世界の記述").font(.subheadline.bold())
                Spacer()
                Text("\(unlocked) / \(entries.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if entries.isEmpty {
                Text("この地域の記述はまだ用意されていない。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries, id: \.entry.id) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.isUnlocked ? "book.closed.fill" : "book.closed")
                            .font(.caption)
                            .foregroundStyle(item.isUnlocked ? Theme.accent : .secondary)
                            .frame(width: 16)

                        // 未解放は本文を出さない。歩いて引き当てる動機がなくなる。
                        Text(item.isUnlocked ? item.entry.text : "まだ読めない")
                            .font(.callout)
                            .foregroundStyle(item.isUnlocked ? .primary : .secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}
