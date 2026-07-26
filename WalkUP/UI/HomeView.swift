import SwiftUI

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
    @State private var milestoneFinds: [MilestoneOpener.Find] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    levelCard
                    resourceRow
                    if game.state.pendingMilestones > 0 { milestoneCard }
                    destinationCard
                    actionRow
                    if let message = game.errorMessage { errorCard(message) }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
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
            .sheet(isPresented: .constant(!milestoneFinds.isEmpty)) {
                MilestoneResultView(finds: milestoneFinds) { milestoneFinds = [] }
            }
        }
    }

    // MARK: - レベル

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lv \(game.player.level)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Spacer()
                if let outcome = game.lastOutcome, outcome.gainedSteps > 0 {
                    Text("+\(outcome.gainedSteps.formatted()) 歩")
                        .font(.footnote.bold())
                        .foregroundStyle(Theme.accent)
                }
            }

            MeterBar(value: game.levelProgress, tint: Theme.accent)

            Text("累計 \(game.player.cumulativeSteps.formatted()) 歩")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var resourceRow: some View {
        HStack(spacing: 12) {
            StatTile(
                title: "今日の歩数", value: game.todaySteps.formatted(),
                systemImage: "figure.walk", tint: Theme.accent
            )
            StatTile(
                title: "活力", value: "\(game.player.ap)",
                systemImage: "bolt.fill", tint: Theme.vigor
            )
            StatTile(
                title: "澱", value: "\(game.dregs)",
                systemImage: "cube", tint: Theme.accent
            )
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
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 次の目的地

    @ViewBuilder
    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("次の目的地").font(.caption).foregroundStyle(.secondary)

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
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
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
        VStack(spacing: 10) {
            Button {
                isShowingMap = true
            } label: {
                Label(game.nextNode == nil ? "周回して素材を集める" : "討伐に出る",
                      systemImage: "map")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentFill)
            // 未挑戦のノードが無くても討伐は続けられる（周回で素材が集まる）。
            // 第1章のゲートに届いていない間だけ閉じる。
            .disabled(!game.canBattle)

            HStack(spacing: 10) {
                Button {
                    isShowingEquipment = true
                } label: {
                    Label("装備・強化", systemImage: "shield.lefthalf.filled")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)

                Button {
                    isShowingPaywall = true
                } label: {
                    Label(purchases.hasPass ? "パス有効" : "活力パス", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
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
        NavigationStack {
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
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("道標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: onClose)
                }
            }
        }
    }
}
