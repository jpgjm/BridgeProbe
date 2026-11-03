//
//  ProbeIntents.swift
//  BridgeProbe
//
//  アラームの停止 / スヌーズに渡す、このアプリ自身の Intent。
//  LiveContainer のことは何も知らない普通の LiveActivityIntent として書く。
//
//  LiveContainer 内では、AlarmKit はこの型を解決できない (登録者が LiveContainer なので)。
//  LiveContainer の TweakLoader (AlarmKitBridge.m) が保存時に LCGuestIntent へ包み替え、
//  押されたらこのアプリを画面なしで起こして、ここの perform() を走らせる。
//
//  ★ で始まる行が出れば「ゲスト自身の Intent が走った」ことの証拠になる。
//

import AlarmKit
import AppIntents
import Foundation

struct ProbeStopIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Probe Stop"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Note")
    var note: String

    @Parameter(title: "Count")
    var count: Int

    init() {
        self.note = ""
        self.count = 0
    }

    init(note: String, count: Int) {
        self.note = note
        self.count = count
    }

    func perform() async throws -> some IntentResult {
        AppLog.info("intent", "★ ProbeStopIntent が実行されました note=\(note) count=\(count) 環境=\(Env.label)")
        return .result()
    }
}

struct ProbeSnoozeIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Probe Snooze"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    /// スヌーズの方式が .custom か。.custom では Intent 自身が鳴動を止める契約。
    @Parameter(title: "Custom")
    var custom: Bool

    init() {
        self.alarmID = ""
        self.custom = false
    }

    init(alarmID: String, custom: Bool) {
        self.alarmID = alarmID
        self.custom = custom
    }

    func perform() async throws -> some IntentResult {
        AppLog.info("intent", "★ ProbeSnoozeIntent が実行されました alarmID=\(alarmID.prefix(8)) custom=\(custom) 環境=\(Env.label)")

        guard custom else { return .result() }
        guard let id = UUID(uuidString: alarmID) else {
            AppLog.error("intent", "★ alarmID が UUID ではありません: \(alarmID)")
            return .result()
        }

        // .custom: AlarmKit は自分では止めない。countdown(id:) でスヌーズ状態に移す。
        // 失敗したら stop(id:) で鳴動だけは止める (鳴り続けるのを避ける)。
        do {
            try AlarmManager.shared.countdown(id: id)
            AppLog.info("intent", "★ countdown(id:) 成功")
        } catch {
            AppLog.error("intent", "★ countdown(id:) 失敗: \(Self.describe(error))")
            do {
                try AlarmManager.shared.stop(id: id)
                AppLog.info("intent", "★ stop(id:) 成功")
            } catch {
                AppLog.error("intent", "★ stop(id:) 失敗: \(Self.describe(error))")
            }
        }
        return .result()
    }

    private static func describe(_ error: Error) -> String {
        let ns = error as NSError
        return "\(ns.domain) code=\(ns.code) \(ns.localizedDescription)"
    }
}
