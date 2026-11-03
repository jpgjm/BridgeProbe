//
//  ProbeAlarmService.swift
//  BridgeProbe
//
//  検証用アラームの登録・状態の監視。
//

import AlarmKit
import Foundation
import SwiftUI

struct ProbeMetadata: AlarmMetadata {}

enum SnoozeMode: String, CaseIterable, Identifiable {
    case countdown
    case custom
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .countdown: return ".countdown (システムがスヌーズ)"
        case .custom: return ".custom (Intent が止める)"
        case .none: return "スヌーズなし"
        }
    }
}

@MainActor
final class ProbeAlarmService: ObservableObject {

    static let shared = ProbeAlarmService()

    @Published private(set) var alarms: [Alarm] = []
    @Published private(set) var authorizationText = "?"
    @Published private(set) var wrapStatus = ""

    private let manager = AlarmManager.shared
    private var lastStates: [UUID: String] = [:]
    private var observing = false

    private static let counterKey = "probe.counter"
    static let lastTestStartKey = "probe.lastTestStart"

    static var lastTestStart: Date? {
        UserDefaults.standard.object(forKey: lastTestStartKey) as? Date
    }

    // MARK: - 権限

    func refreshAuthorization() {
        authorizationText = Self.text(manager.authorizationState)
    }

    func requestAuthorization() async {
        do {
            let state = try await manager.requestAuthorization()
            authorizationText = Self.text(state)
            AppLog.info("alarm", "権限: \(authorizationText)")
        } catch {
            AppLog.error("alarm", "権限の要求に失敗: \(error)")
        }
    }

    private static func text(_ state: AlarmManager.AuthorizationState) -> String {
        switch state {
        case .authorized: return "許可"
        case .denied: return "拒否"
        case .notDetermined: return "未決定"
        @unknown default: return "不明"
        }
    }

    // MARK: - 監視

    /// アプリが動いている間だけ、アラームの状態の変化を時刻付きで記録する。
    func startObserving() {
        guard !observing else { return }
        observing = true
        reload()
        Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                await MainActor.run { self?.apply(alarms) }
            }
        }
    }

    func reload() {
        apply((try? manager.alarms) ?? [])
    }

    private func apply(_ alarms: [Alarm]) {
        self.alarms = alarms
        var current: [UUID: String] = [:]
        for alarm in alarms {
            let state = String(describing: alarm.state)
            current[alarm.id] = state
            if lastStates[alarm.id] != state {
                AppLog.info("alarm", "状態: \(alarm.id.uuidString.prefix(8)) \(lastStates[alarm.id] ?? "(新規)") → \(state)")
            }
        }
        for (id, state) in lastStates where current[id] == nil {
            AppLog.info("alarm", "状態: \(id.uuidString.prefix(8)) \(state) → (登録なし)")
        }
        lastStates = current
    }

    // MARK: - 登録

    func schedule(afterSeconds seconds: Int, mode: SnoozeMode, snoozeSeconds: Int) async {
        if manager.authorizationState != .authorized {
            await requestAuthorization()
        }

        let count = UserDefaults.standard.integer(forKey: Self.counterKey) + 1
        UserDefaults.standard.set(count, forKey: Self.counterKey)
        let start = Date()
        UserDefaults.standard.set(start, forKey: Self.lastTestStartKey)

        let id = UUID()
        let note = "テスト #\(count)"
        let stopButton = AlarmButton(text: "停止", textColor: .white, systemImageName: "stop.circle.fill")
        let title = LocalizedStringResource(stringLiteral: "Probe #\(count) \(mode.rawValue)")

        let alert: AlarmPresentation.Alert
        let countdownDuration: Alarm.CountdownDuration?
        switch mode {
        case .countdown, .custom:
            let snoozeButton = AlarmButton(text: "スヌーズ", textColor: .white, systemImageName: "moon.zzz.fill")
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: mode == .custom ? .custom : .countdown
            )
            countdownDuration = Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(snoozeSeconds))
        case .none:
            alert = AlarmPresentation.Alert(title: title, stopButton: stopButton)
            countdownDuration = nil
        }

        let attributes = AlarmAttributes<ProbeMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .blue
        )
        let schedule = Alarm.Schedule.fixed(start.addingTimeInterval(TimeInterval(seconds)))
        let stopIntent = ProbeStopIntent(note: note, count: count)

        do {
            if mode == .none {
                let configuration = AlarmManager.AlarmConfiguration<ProbeMetadata>(
                    countdownDuration: countdownDuration,
                    schedule: schedule,
                    attributes: attributes,
                    stopIntent: stopIntent,
                    secondaryIntent: nil as ProbeSnoozeIntent?,
                    sound: .default
                )
                _ = try await manager.schedule(id: id, configuration: configuration)
            } else {
                let configuration = AlarmManager.AlarmConfiguration<ProbeMetadata>(
                    countdownDuration: countdownDuration,
                    schedule: schedule,
                    attributes: attributes,
                    stopIntent: stopIntent,
                    secondaryIntent: ProbeSnoozeIntent(alarmID: id.uuidString, custom: mode == .custom),
                    sound: .default
                )
                _ = try await manager.schedule(id: id, configuration: configuration)
            }
            AppLog.info("alarm", "──── 登録: \(note) \(seconds) 秒後 スヌーズ=\(mode.rawValue) (\(snoozeSeconds) 秒) id=\(id.uuidString.prefix(8)) 環境=\(Env.label)")
        } catch {
            let ns = error as NSError
            AppLog.error("alarm", "登録に失敗: \(ns.domain) code=\(ns.code) \(ns.localizedDescription)")
        }

        reload()
        await checkWrapping(since: start)
    }

    /// 登録直後に bridge.log を見て、包み替えが起きたかを画面に出す。
    private func checkWrapping(since start: Date) async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard Env.isLiveContainer else {
            wrapStatus = "直インストールなので包み替えは起きません (Intent はこのアプリで直接解決されます)"
            return
        }
        let entries = MergedLog.entries(from: [.bridge], since: start)
        let wraps = entries.filter { $0.text.contains("包み替え:") }
        if wraps.isEmpty {
            wrapStatus = "包み替えの記録がありません。LiveContainer が diag2.4 以降か、TweakLoader が読み込まれているかを確認してください"
        } else {
            let fromHost = wraps.filter { $0.text.contains("LiveContainer のメタデータから") }.count
            wrapStatus = "包み替え \(wraps.count) 件 (LiveContainer のメタデータから \(fromHost) 件)"
        }
        AppLog.info("alarm", "包み替えの確認: \(wrapStatus)")
    }

    // MARK: - 取り消し

    func cancel(_ id: UUID) {
        do {
            try manager.cancel(id: id)
            AppLog.info("alarm", "取り消し: \(id.uuidString.prefix(8))")
        } catch {
            AppLog.error("alarm", "取り消しに失敗: \(error)")
        }
        reload()
    }

    func cancelAll() {
        for alarm in alarms { cancel(alarm.id) }
    }
}
