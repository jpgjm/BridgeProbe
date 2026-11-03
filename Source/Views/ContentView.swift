//
//  ContentView.swift
//  BridgeProbe
//

import AlarmKit
import SwiftUI

struct ContentView: View {

    @StateObject private var service = ProbeAlarmService.shared
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("probe.delaySeconds") private var delaySeconds = 30
    @AppStorage("probe.snoozeMode") private var snoozeModeRaw = SnoozeMode.countdown.rawValue
    @AppStorage("probe.snoozeSeconds") private var snoozeSeconds = 60

    @State private var showLog = false
    @State private var starCount = 0
    @State private var sourceStatus: [LogSource: Bool] = [:]

    private var snoozeMode: SnoozeMode { SnoozeMode(rawValue: snoozeModeRaw) ?? .countdown }

    var body: some View {
        NavigationStack {
            Form {
                Section("環境") {
                    LabeledContent("実行環境", value: Env.label)
                    LabeledContent("バージョン", value: Env.appVersion)
                    LabeledContent("AlarmKit の権限", value: service.authorizationText)
                    ForEach(LogSource.allCases) { source in
                        LabeledContent("ログ [\(source.rawValue)]",
                                       value: sourceStatus[source] == true ? "あり" : "なし")
                    }
                    if !Env.isLiveContainer {
                        Text("LiveContainer の外で動いています。比較用 (Intent はこのアプリで直接解決されます)。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Stepper("鳴るまで \(delaySeconds) 秒", value: $delaySeconds, in: 10...600, step: 10)
                    Picker("スヌーズ", selection: $snoozeModeRaw) {
                        ForEach(SnoozeMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    if snoozeMode != .none {
                        Stepper("スヌーズ後 \(snoozeSeconds) 秒で再鳴動", value: $snoozeSeconds, in: 30...600, step: 30)
                    }
                    Button {
                        Task { await service.schedule(afterSeconds: delaySeconds, mode: snoozeMode, snoozeSeconds: snoozeSeconds) ; refresh() }
                    } label: {
                        Label("アラームを登録", systemImage: "alarm")
                    }
                    if !service.wrapStatus.isEmpty {
                        Text(service.wrapStatus).font(.footnote)
                    }
                } header: {
                    Text("テスト")
                } footer: {
                    Text("登録したら画面をロックして待ち、鳴ったら停止かスヌーズを 1 回だけ押します。連打すると LiveContainer が新しい子プロセスを起動できず、記録が乱れます。終わったらこのアプリを開き「統合ログ」を共有してください。")
                }

                Section("結果 (直近のテスト)") {
                    LabeledContent("★ Intent の実行", value: "\(starCount) 回")
                    Button("統合ログを開く") { showLog = true }
                }

                Section("登録中のアラーム") {
                    if service.alarms.isEmpty {
                        Text("なし").foregroundStyle(.secondary)
                    }
                    ForEach(service.alarms, id: \.id) { alarm in
                        HStack {
                            Text(alarm.id.uuidString.prefix(8)).font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(String(describing: alarm.state)).foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("取り消す", role: .destructive) { service.cancel(alarm.id) }
                        }
                    }
                    if !service.alarms.isEmpty {
                        Button("すべて取り消す", role: .destructive) { service.cancelAll() }
                    }
                }
            }
            .navigationTitle("BridgeProbe")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showLog = true } label: { Image(systemName: "doc.text.magnifyingglass") }
                }
            }
            .sheet(isPresented: $showLog) { LogViewerSheet() }
            .task {
                service.refreshAuthorization()
                service.startObserving()
                refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    service.refreshAuthorization()
                    service.reload()
                    refresh()
                }
            }
        }
    }

    private func refresh() {
        starCount = MergedLog.starCount(since: ProbeAlarmService.lastTestStart)
        var status: [LogSource: Bool] = [:]
        for source in LogSource.allCases {
            status[source] = source.url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        }
        sourceStatus = status
    }
}
