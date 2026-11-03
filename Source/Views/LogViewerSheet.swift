//
//  LogViewerSheet.swift
//  BridgeProbe
//
//  統合ログの表示と共有。シートで出す。
//

import SwiftUI

struct LogViewerSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var onlyLastTest = true
    @State private var text = ""
    @State private var exportURL: URL?
    @State private var confirmClear = false

    private var since: Date? { onlyLastTest ? ProbeAlarmService.lastTestStart : nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("範囲", selection: $onlyLastTest) {
                    Text("直近のテスト以降").tag(true)
                    Text("全部").tag(false)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView([.vertical, .horizontal]) {
                    Text(text.isEmpty ? "(ログがありません)" : text)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("統合ログ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { reload() } label: { Image(systemName: "arrow.clockwise") }
                    if let exportURL {
                        ShareLink(item: exportURL) { Image(systemName: "square.and.arrow.up") }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("このアプリのログを消す", role: .destructive) { confirmClear = true }
                }
            }
            .confirmationDialog("このアプリのログ (bridge-probe.log と bridge.log) を消しますか？ LiveContainer のログは消しません。",
                                isPresented: $confirmClear, titleVisibility: .visible) {
                Button("消す", role: .destructive) { clearOwnLogs() }
            }
            .onAppear { reload() }
            .onChange(of: onlyLastTest) { reload() }
        }
    }

    private func reload() {
        text = MergedLog.format(MergedLog.entries(since: since))
        exportURL = MergedLog.exportFile(since: since)
    }

    private func clearOwnLogs() {
        for url in [Env.probeLogURL, Env.bridgeLogURL] {
            try? FileManager.default.removeItem(at: url)
        }
        AppLog.info("log", "このアプリのログを消しました")
        reload()
    }
}
