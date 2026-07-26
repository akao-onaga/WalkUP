import SwiftUI

/// 装備・強化（画面 #4）。
///
/// §4.1 のとおり **ここが唯一の意思決定**。戦闘は自動なので、勝敗はこの画面で決まる。
struct EquipmentView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    if game.state.equipment.isEmpty {
                        emptyState
                    } else {
                        ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                            slotSection(slot)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("装備・強化")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    // ツールバーの Label は既定でアイコンのみに畳まれる。
                    // 強化に足りるか判断できないと意味がないので明示する。
                    Label("\(game.dregs)", systemImage: "cube")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    /// 装備を変えた効果がその場で数字に出るようにする。
    /// 自動戦闘なので、ここで手応えを返せないと意思決定が空虚になる。
    private var statusCard: some View {
        let fighter = game.playerFighter
        return HStack(spacing: 12) {
            StatTile(title: "HP", value: "\(fighter.maxHP)", systemImage: "heart.fill")
            StatTile(title: "ATK", value: "\(fighter.atk)", systemImage: "flame.fill", tint: Theme.vigor)
            StatTile(title: "DEF", value: "\(fighter.def)", systemImage: "shield.fill")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("まだ装備がありません")
                .font(.headline)
            Text("各章のノード 2・4・6 を討伐すると手に入ります。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func slotSection(_ slot: EquipmentSlot) -> some View {
        let items = game.state.equipment.filter { $0.slot == slot }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(slotName(slot))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let note = slotNote(slot) {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ForEach(items) { item in
                    equipmentRow(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func equipmentRow(_ item: Equipment) -> some View {
        let effective = item.effective
        let cost = BalanceRules.enhanceCost(currentLevel: item.enhanceLevel)
        let isMaxed = item.enhanceLevel >= BalanceRules.maxEnhanceLevel

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.name).font(.subheadline.bold())
                        if item.enhanceLevel > 0 {
                            Text("+\(item.enhanceLevel)")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.vigor)
                        }
                    }
                    Text(statLine(effective))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(item.isEquipped ? "装備中" : "装備") {
                    game.toggleEquip(item)
                }
                .buttonStyle(.bordered)
                .tint(item.isEquipped ? Theme.accentFill : Theme.accent)
            }

            HStack(spacing: 10) {
                MeterBar(
                    value: Double(item.enhanceLevel) / Double(BalanceRules.maxEnhanceLevel),
                    tint: Theme.vigor
                )
                if isMaxed {
                    Text("最大")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        game.enhance(item)
                    } label: {
                        Label("\(cost)", systemImage: "hammer.fill")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .disabled(!game.canEnhance(item))
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func statLine(_ stats: (hp: Int, atk: Int, def: Int)) -> String {
        var parts: [String] = []
        if stats.hp > 0 { parts.append("HP +\(stats.hp)") }
        if stats.atk > 0 { parts.append("ATK +\(stats.atk)") }
        if stats.def > 0 { parts.append("DEF +\(stats.def)") }
        return parts.joined(separator: " / ")
    }

    private func slotName(_ slot: EquipmentSlot) -> String {
        switch slot {
        case .weapon: return "武器 — 靴"
        case .armor: return "防具"
        case .accessory: return "装飾"
        }
    }

    /// 武器が靴であることの説明。**この設定は放っておくと伝わらない。**
    /// 「武器」の欄に靴が並ぶ理由が分かるのは、ここに一行あるときだけ。
    private func slotNote(_ slot: EquipmentSlot) -> String? {
        switch slot {
        case .weapon: return "この世界で武器になるのは踏み出す力——ウォーク力だけ。"
        default: return nil
        }
    }
}

/// 設定（画面 #9）。権限・デモモード・復元。
struct SettingsView: View {
    @Environment(GameModel.self) private var game
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("データ元", selection: Binding(
                        get: { game.source },
                        set: { game.source = $0 }
                    )) {
                        ForEach(GameModel.StepSource.allCases) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    // §11-1: 審査員は歩かない。デモモードは審査対策の中核。
                    Text("シミュレータにはヘルスケアの歩数が存在しません。デモは App Review と審査員向けの体験モードも兼ねます。")
                }

                Section("直近7日") {
                    ForEach(game.recentSteps) { day in
                        HStack {
                            Text(day.date, format: .dateTime.month(.abbreviated).day().weekday(.abbreviated))
                            Spacer()
                            Text(day.steps, format: .number)
                                .monospacedDigit()
                                .foregroundStyle(day.steps == 0 ? .secondary : .primary)
                        }
                    }
                }

                Section("購入") {
                    Button("購入を復元") {
                        Task { await purchases.restore() }
                    }
                    .disabled(purchases.availability != .ready)

                    Link("プライバシーポリシー", destination: LegalURL.privacyPolicy)
                    Link("利用規約", destination: LegalURL.termsOfUse)
                }

                #if DEBUG
                Section("開発用") {
                    Button("歩数を +4,000 する") { game.debugAddSteps(4_000) }
                    Button("歩数を +20,000 する") { game.debugAddSteps(20_000) }
                }
                #endif
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
