import SwiftUI

/// HealthKit 疎通確認用の暫定画面。
/// ゲーム本体の実装が始まったら差し替える。
struct ContentView: View {
    @Environment(PurchaseManager.self) private var purchases
    @State private var model = StepDashboardModel()
    @State private var isShowingPaywall = false

    var body: some View {
        NavigationStack {
            List {
                sourceSection
                todaySection
                chapterGateSection
                passSection
                historySection
                if let message = model.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("歩数の疎通確認")
            .toolbar {
                Button {
                    Task { await model.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
            }
            .task { await model.requestAuthorizationAndLoad() }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
            }
        }
    }

    /// ペイウォールへの暫定導線。ホーム画面を作り込む段階で正式な位置に移す。
    private var passSection: some View {
        Section("活力パス") {
            Button {
                isShowingPaywall = true
            } label: {
                HStack {
                    Label(
                        purchases.hasPass ? "有効" : "活力パスを見る",
                        systemImage: purchases.hasPass ? "checkmark.seal.fill" : "sparkles"
                    )
                    Spacer()
                    if purchases.availability == .disabled {
                        Text("キー未設定")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        Section {
            Picker("データ元", selection: $model.source) {
                ForEach(StepDashboardModel.Source.allCases) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text("シミュレータにはヘルスケアの歩数が存在しません。デモは App Review と審査員向けの体験モードも兼ねます。")
        }
    }

    private var todaySection: some View {
        Section("今日") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.today, format: .number)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("歩")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isLoading {
                    ProgressView()
                }
            }
        }
    }

    private var chapterGateSection: some View {
        Section("第1章の解放（暫定 \(StepDashboardModel.chapterOneGoal.formatted()) 歩）") {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: model.chapterOneProgress)
                Text("直近7日の累計 \(model.cappedTotal.formatted()) 歩")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var historySection: some View {
        Section("直近7日") {
            if model.history.isEmpty {
                Text("データがありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.history) { day in
                    HStack {
                        Text(day.date, format: .dateTime.month(.abbreviated).day().weekday(.abbreviated))
                        Spacer()
                        if day.steps > StepDashboardModel.dailyStepCap {
                            Text("上限")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                        }
                        Text(day.steps, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(day.steps == 0 ? .secondary : .primary)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(PurchaseManager())
}
