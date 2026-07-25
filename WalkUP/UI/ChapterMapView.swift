import SwiftUI

/// 章／ノード選択（画面 #2）。
///
/// §5.1 のとおり各章8ノードの固定エンカウント。歩数ゲートに届いていない章は開かない。
struct ChapterMapView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    @State private var session: GameModel.BattleSession?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(1...3, id: \.self) { chapter in
                        chapterSection(chapter)
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("討伐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    // ツールバーの Label は既定でアイコンのみに畳まれる。
                    // 残量が読めないと AP の消費判断ができないので明示する。
                    Label("\(game.player.ap)", systemImage: "bolt.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.vigor)
                }
            }
            .fullScreenCover(item: $session) { session in
                BattleView(session: session)
            }
            .alert("挑めません", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func chapterSection(_ chapter: Int) -> some View {
        let gate = MasterData.chapterGate(chapter)
        let isOpen = game.player.cumulativeSteps >= gate

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("第\(chapter)章").font(.headline)
                Spacer()
                if !isOpen {
                    Label("\(gate.formatted()) 歩で解放", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if game.progress(for: chapter).isCleared {
                    Label("クリア", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            }

            if isOpen {
                ForEach(1...MasterData.nodesPerChapter, id: \.self) { index in
                    nodeRow(chapter: chapter, index: index)
                }
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .opacity(isOpen ? 1 : 0.55)
    }

    private func nodeRow(chapter: Int, index: Int) -> some View {
        let node = MasterData.node(chapter: chapter, index: index)
        let cleared = game.isNodeCleared(chapter: chapter, index: index)
        let unlocked = game.isNodeUnlocked(chapter: chapter, index: index)
        let affordable = game.player.ap >= node.enemy.apCost

        return Button {
            do {
                session = try game.startBattle(chapter: chapter, nodeIndex: index)
            } catch {
                errorMessage = error.localizedDescription
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(cleared ? Theme.accent : (unlocked ? Theme.accent.opacity(0.2) : Color.gray.opacity(0.15)))
                        .frame(width: 32, height: 32)
                    if cleared {
                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                    } else if unlocked {
                        Text("\(index)").font(.caption.bold())
                    } else {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.enemy.isBoss ? "ボス：\(node.enemy.name)" : node.enemy.name)
                        .font(.subheadline.weight(node.enemy.isBoss ? .bold : .regular))
                    if node.equipmentReward != nil {
                        Label("装備を入手", systemImage: "shield.lefthalf.filled")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                    }
                }

                Spacer()

                Label("\(node.enemy.apCost)", systemImage: "bolt.fill")
                    .font(.caption.bold())
                    .foregroundStyle(affordable ? Theme.vigor : .secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

extension GameModel.BattleSession: Identifiable {
    var id: String { "\(chapter)-\(nodeIndex)-\(log.turnCount)-\(log.result.rawValue)" }
}
