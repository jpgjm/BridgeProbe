//
//  AppLog.swift
//  BridgeProbe
//
//  重要度付きのアプリ内ログ。Documents/bridge-probe.log に追記する。
//  画面なしで起こされたとき (LiveProcess) もここに残るので、
//  Intent が走ったかどうかはこのファイルで判定する。
//

import Foundation
import os

enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

enum AppLog {

    private static let lock = NSLock()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BridgeProbe", category: "app")

    /// 行頭の書式。統合ログの読み取り (MergedLog) と合わせること。
    static let lineDateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = lineDateFormat
        return f
    }()

    static func debug(_ category: String, _ message: String) { write(.debug, category, message) }
    static func info(_ category: String, _ message: String) { write(.info, category, message) }
    static func warning(_ category: String, _ message: String) { write(.warning, category, message) }
    static func error(_ category: String, _ message: String) { write(.error, category, message) }

    static func write(_ level: LogLevel, _ category: String, _ message: String) {
        let line = "\(formatter.string(from: Date())) [\(level.rawValue)] [\(category)] pid=\(getpid()) \(message)\n"
        logger.log("\(line, privacy: .public)")
        guard let data = line.data(using: .utf8) else { return }

        lock.lock()
        defer { lock.unlock() }
        let url = Env.probeLogURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}
