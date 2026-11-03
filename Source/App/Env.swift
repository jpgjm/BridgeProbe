//
//  Env.swift
//  BridgeProbe
//
//  実行環境の判定と、ログの置き場所。
//
//  LiveContainer は HOME を差し替える前に本来の HOME を LC_HOME_PATH に退避する。
//  LiveProcess (画面なしの子プロセス) では LP_HOME_PATH も入る。
//

import Foundation

enum Env {

    static let lcHomePath: String? = ProcessInfo.processInfo.environment["LC_HOME_PATH"]

    static var isLiveContainer: Bool { lcHomePath != nil }

    static var isLiveProcess: Bool {
        if ProcessInfo.processInfo.environment["LP_HOME_PATH"] != nil { return true }
        return (Bundle.main.executablePath ?? "").contains("LiveProcess.appex")
    }

    static var label: String {
        if isLiveProcess { return "LiveContainer (LiveProcess)" }
        return isLiveContainer ? "LiveContainer" : "直インストール"
    }

    static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - ログの場所

    /// このアプリ自身のログ
    static var probeLogURL: URL { documents.appendingPathComponent("bridge-probe.log") }

    /// LiveContainer の TweakLoader (AlarmKitBridge.m) がこのアプリのコンテナに書くログ
    static var bridgeLogURL: URL { documents.appendingPathComponent("LCBridge/bridge.log") }

    /// LiveContainer 本体 (LCGuestIntent) のログ。LiveContainer 内でだけ読める
    static var lcLogURL: URL? {
        guard let home = lcHomePath else { return nil }
        return URL(fileURLWithPath: home, isDirectory: true)
            .appendingPathComponent("Documents/lc-guest-intent.log")
    }
}
