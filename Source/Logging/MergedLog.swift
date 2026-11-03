//
//  MergedLog.swift
//  BridgeProbe
//
//  3 か所のログを時刻順に 1 つにまとめる。
//
//    | 印 | ファイル | 書く人 |
//    |---|---|---|
//    | [Probe] | Documents/bridge-probe.log | このアプリ (Intent の ★ 行、アラームの状態) |
//    | [Bridge] | Documents/LCBridge/bridge.log | LiveContainer の TweakLoader (包み替え・画面なしでの実行) |
//    | [LC] | <LC_HOME_PATH>/Documents/lc-guest-intent.log | LiveContainer 本体 (Intent の受け取り・LiveProcess の起動) |
//
//  [LC] は LiveContainer のコンテナにあるが、ゲストは同じサンドボックスで動くので読める。
//

import Foundation

enum LogSource: String, CaseIterable, Identifiable {
    case probe = "Probe"
    case bridge = "Bridge"
    case lc = "LC"

    var id: String { rawValue }

    var url: URL? {
        switch self {
        case .probe: return Env.probeLogURL
        case .bridge: return Env.bridgeLogURL
        case .lc: return Env.lcLogURL
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let source: LogSource
    var text: String
}

enum MergedLog {

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let localFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = AppLog.lineDateFormat
        return f
    }()

    private static let outputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// 行頭の時刻を読む。読めなければ nil (前の行の続きとして扱う)。
    private static func leadingDate(_ line: Substring) -> (Date, Substring)? {
        if line.hasPrefix("["), let close = line.firstIndex(of: "]") {
            let stamp = line[line.index(after: line.startIndex)..<close]
            if let date = isoFormatter.date(from: String(stamp)) {
                return (date, line[line.index(after: close)...].drop(while: { $0 == " " }))
            }
        }
        if line.count >= 23 {
            let stamp = line.prefix(23)
            if let date = localFormatter.date(from: String(stamp)) {
                return (date, line.dropFirst(23).drop(while: { $0 == " " }))
            }
        }
        return nil
    }

    static func read(_ source: LogSource) -> [LogEntry] {
        guard let url = source.url, let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var entries: [LogEntry] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if let (date, rest) = leadingDate(line) {
                entries.append(LogEntry(date: date, source: source, text: String(rest)))
            } else if !entries.isEmpty {
                entries[entries.count - 1].text += "\n" + line
            } else {
                entries.append(LogEntry(date: .distantPast, source: source, text: String(line)))
            }
        }
        return entries
    }

    static func entries(from sources: [LogSource] = LogSource.allCases, since: Date? = nil) -> [LogEntry] {
        var all: [LogEntry] = []
        for source in sources { all.append(contentsOf: read(source)) }
        if let since {
            // 登録の少し前 (2 秒) から含める。時計の書き方の違いで取りこぼさないため。
            let from = since.addingTimeInterval(-2)
            all = all.filter { $0.date >= from }
        }
        // 時刻順。同時刻はファイル内の順序を保つ (sort は安定)
        return all.enumerated().sorted { lhs, rhs in
            lhs.element.date == rhs.element.date ? lhs.offset < rhs.offset : lhs.element.date < rhs.element.date
        }.map(\.element)
    }

    static func format(_ entries: [LogEntry]) -> String {
        entries.map { entry in
            let time = entry.date == .distantPast ? "--:--:--.---" : outputFormatter.string(from: entry.date)
            let source = "[\(entry.source.rawValue)]".padding(toLength: 8, withPad: " ", startingAt: 0)
            return "\(time) \(source) \(entry.text)"
        }.joined(separator: "\n")
    }

    /// 共有用のファイルを作る。冒頭に環境と各ファイルの有無を書く。
    static func exportFile(since: Date?) -> URL? {
        var header = "BridgeProbe \(Env.appVersion) 統合ログ\n"
        header += "環境: \(Env.label)\n"
        header += "書き出し: \(Date())\n"
        header += "範囲: \(since.map { "\($0) 以降 (直近のテスト)" } ?? "全部")\n"
        for source in LogSource.allCases {
            let exists = source.url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            header += "  [\(source.rawValue)] \(source.url?.path ?? "(LiveContainer 外では無し)") \(exists ? "あり" : "なし")\n"
        }
        header += String(repeating: "─", count: 40) + "\n"
        let body = format(entries(since: since))

        let stamp: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyyMMdd-HHmmss"
            return f.string(from: Date())
        }()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BridgeProbe-log-\(stamp).txt")
        do {
            try (header + body + "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            AppLog.error("log", "書き出しに失敗: \(error)")
            return nil
        }
    }

    /// ★ 行 (ゲスト自身の Intent が走った印) の数
    static func starCount(since: Date?) -> Int {
        entries(from: [.probe], since: since).filter { $0.text.contains("★") && $0.text.contains("実行されました") }.count
    }
}
