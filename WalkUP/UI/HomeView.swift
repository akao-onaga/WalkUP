import SwiftUI
import UIKit

/// ホーム（画面 #1）。今日の歩数・活力・レベル・次の目的地。
///
/// §2 の「夜アプリを開いて1セッション3分」の入口。
/// 開いた瞬間に「今日も無駄じゃなかった」が分かることを最優先にしている。
struct HomeView: View {
    @Environment(GameModel.self) private var game
    @Environment(PurchaseManager.self) private var purchases

    @State private var isShowingMap = false
    @State private var isShowingEquipment = false
    @State private var isShowingPaywall = false
    @State private var isShowingSettings = false
    @State private var isShowingRegions = false
    @State private var isShowingBestiary = false
    @State private var milestoneFinds: [MilestoneOpener.Find] = []
    @State private var gaugeShown = false
    @State private var levelBadgePopped = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroStrip
                    levelCard
                    resourceRow
                    if game.state.pendingMilestones > 0 { milestoneCard }
                    destinationCard
                    actionRow
                    if let message = game.errorMessage { errorCard(message) }
                }
                .padding(16)
            }
            .background(homeBackdrop.ignoresSafeArea())
            .navigationTitle("Walk UP!")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task {
                game.hasPass = purchases.hasPass
                await game.requestAuthorizationAndRefresh()
            }
            .onChange(of: purchases.hasPass) { _, newValue in game.hasPass = newValue }
            .refreshable { await game.refresh() }
            .sheet(isPresented: $isShowingMap) { ChapterMapView() }
            .sheet(isPresented: $isShowingEquipment) { EquipmentView() }
            .sheet(isPresented: $isShowingPaywall) { PaywallView() }
            .sheet(isPresented: $isShowingSettings) { SettingsView() }
            .sheet(isPresented: $isShowingRegions) { RegionView() }
            .sheet(isPresented: $isShowingBestiary) { BestiaryView() }
            .sheet(isPresented: .constant(!milestoneFinds.isEmpty)) {
                MilestoneResultView(finds: milestoneFinds) { milestoneFinds = [] }
            }
        }
    }

    // MARK: - 世界を敷く

    /// ホームの背景。**今いる地域を薄く敷く。**
    ///
    /// 無地の背景だと、毎日最初に開く画面がゲームの外側に見える。
    /// ただし主役は数値なので、**読めなくなる手前まで沈める**。
    private var homeBackdrop: some View {
        ZStack {
            Theme.background

            if UIImage(named: "bg\(game.unlockedChapter)") != nil {
                Image("bg\(game.unlockedChapter)")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.55)
                    .blur(radius: 1)
                    // カードが乗る中央〜下は濃く覆い、上だけ街を見せる。
                    // 全面を均一に沈めると、ぼやけた汚れにしか見えない。
                    .overlay(
                        LinearGradient(
                            colors: [
                                Theme.background.opacity(0.15),
                                Theme.background.opacity(0.85),
                                Theme.background
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
        }
    }

    /// 主人公。**この世界で唯一動いている存在**（§1）なので、待機でも止めない。
    private var heroStrip: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HeroPortrait()
                .frame(width: 96, height: 96)
                .modifier(IdleBob(active: true))
                .shadow(color: Theme.ink.opacity(0.35), radius: 0, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(game.todaySteps > 0 ? "今日も歩いた" : "まだ歩いていない")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                Text(game.todaySteps > 0
                     ? "その分だけ、世界が目を覚ます。"
                     : "一歩ごとに、止まった街が動き出す。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - レベル

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Lv \(game.player.level)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())

                // レベルが上がった日だけ出す。毎回出すと祝いの意味が消える。
                if let outcome = game.lastOutcome, outcome.levelsGained > 0 {
                    Text("Lv UP")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.vigor, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: Theme.strokeWidth))
                        .scaleEffect(levelBadgePopped ? 1 : 1.6)
                        .opacity(levelBadgePopped ? 1 : 0)
                }

                Spacer()

                if let outcome = game.lastOutcome, outcome.gainedSteps > 0 {
                    // 今日の増分。**ここが「歩いた甲斐」の本体**なので、静止させない。
                    HStack(spacing: 2) {
                        Text("+")
                        CountUp(target: outcome.gainedSteps)
                        Text(" 歩")
                    }
                    .font(.system(.footnote, design: .rounded).weight(.heavy).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                }
            }

            // ゲージは 0 から伸ばす。到達点だけ置くと、伸びた実感が残らない。
            MeterBar(value: gaugeShown ? game.levelProgress : 0, tint: Theme.accent)

            Text("累計 \(game.player.cumulativeSteps.formatted()) 歩")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .panel()
        .task {
            withAnimation(.easeOut(duration: 0.8)) { gaugeShown = true }
            guard let outcome = game.lastOutcome, outcome.levelsGained > 0 else { return }
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { levelBadgePopped = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private var resourceRow: some View {
        HStack(spacing: 12) {
            StatTile(title: "今日の歩数", count: game.todaySteps,
                     systemImage: "figure.walk", tint: Theme.accent)
            StatTile(title: "活力", count: game.player.ap,
                     systemImage: "bolt.fill", tint: Theme.vigor)
            StatTile(title: "澱", count: game.dregs,
                     systemImage: "cube", tint: Theme.accent)
        }
    }

    // MARK: - 道標（§18）

    private var milestoneCard: some View {
        Button {
            milestoneFinds = game.openMilestones()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "signpost.right.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accentFill)
                VStack(alignment: .leading, spacing: 2) {
                    Text("道標が \(game.state.pendingMilestones) つ")
                        .font(.headline)
                    Text("歩いた道のりに、何かが残されている")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.ink.opacity(0.6))
            }
            .contentShape(Rectangle())
            .panel(fill: Theme.accent.opacity(0.28))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 次の目的地

    @ViewBuilder
    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "次の目的地")

            if let next = game.nextNode {
                let node = MasterData.node(chapter: next.chapter, index: next.index)
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("第\(next.chapter)章 ノード \(next.index)").font(.headline)
                        Text(node.enemy.isBoss ? "ボス：\(node.enemy.name)" : node.enemy.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("\(node.enemy.apCost)", systemImage: "bolt.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(game.player.ap >= node.enemy.apCost ? Theme.vigor : .secondary)
                }
            } else if let gate = nextGate {
                // 歩数ゲートに届いていない状態。ここで「歩けば開く」ことを明示する。
                VStack(alignment: .leading, spacing: 8) {
                    Text("第\(gate.chapter)章の解放まで あと \(gate.remaining.formatted()) 歩")
                        .font(.headline)
                    MeterBar(value: gate.progress, tint: Theme.accent)

                    if game.canBattle {
                        // ここを書かないと「詰んだ」ように見える。周回できることを明示する。
                        Text("解放を待つ間も、討伐済みのダルモンに再挑戦して素材を集められます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("本編は完結しました。地域の復興を進められます。")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    private var nextGate: (chapter: Int, remaining: Int, progress: Double)? {
        for chapter in 1...3 {
            let gate = MasterData.chapterGate(chapter)
            if game.player.cumulativeSteps < gate {
                let previous = chapter > 1 ? MasterData.chapterGate(chapter - 1) : 0
                let span = max(1, gate - previous)
                return (
                    chapter,
                    gate - game.player.cumulativeSteps,
                    Double(game.player.cumulativeSteps - previous) / Double(span)
                )
            }
        }
        return nil
    }

    // MARK: - 導線

    private var actionRow: some View {
        VStack(spacing: 12) {
            Button {
                isShowingMap = true
            } label: {
                Label(game.nextNode == nil ? "周回して素材を集める" : "討伐に出る",
                      systemImage: "map")
            }
            .buttonStyle(InkButtonStyle())
            // 未挑戦のノードが無くても討伐は続けられる（周回で素材が集まる）。
            // 第1章のゲートに届いていない間だけ閉じる。
            .disabled(!game.canBattle)
            .opacity(game.canBattle ? 1 : 0.5)

            HStack(spacing: 12) {
                Button { isShowingEquipment = true } label: {
                    Label("装備・強化", systemImage: "shield.lefthalf.filled")
                }
                .buttonStyle(InkSecondaryButtonStyle())

                Button { isShowingPaywall = true } label: {
                    Label(purchases.hasPass ? "パス有効" : "活力パス", systemImage: "sparkles")
                }
                .buttonStyle(InkSecondaryButtonStyle())
            }

            // 収集の導線。討伐に出られない日でも開く場所として置いている。
            HStack(spacing: 12) {
                Button { isShowingRegions = true } label: {
                    Label("地域", systemImage: "map.circle")
                }
                .buttonStyle(InkSecondaryButtonStyle())

                Button { isShowingBestiary = true } label: {
                    Label("図鑑", systemImage: "book.closed")
                }
                .buttonStyle(InkSecondaryButtonStyle())
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(Theme.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 道標の開封結果

struct MilestoneResultView: View {
    let finds: [MilestoneOpener.Find]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(title: "道標", onClose: onClose)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(finds.enumerated()), id: \.offset) { _, find in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: find.icon)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(find.title).font(.subheadline.bold())
                                if case .lore(_, let text) = find {
                                    Text(text)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                                                .panel(radius: 14, inset: 14)
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
