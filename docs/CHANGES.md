# 変更履歴

## v2.0.0 (2026-11-03)

v1.0.0 を作り直した。

- 統合ログ: このアプリ・ブリッジ (bridge.log)・LiveContainer (lc-guest-intent.log) を時刻順に 1 つにまとめ、ファイルで共有できる
- 登録直後に bridge.log を見て、包み替えが起きたかを画面に出す
- アラームの状態の変化 (`alarmUpdates`) を時刻付きで記録する (スヌーズ後の挙動の確認用)
- スヌーズの方式 (`.countdown` / `.custom` / なし)、鳴るまでの秒数、再鳴動までの秒数を選べる
- `.custom` のスヌーズでは `AlarmManager.countdown(id:)` を呼ぶ (失敗したら `stop(id:)`)
- Intent の型名・引数は v1 と同じ (`ProbeStopIntent(note, count)` / `ProbeSnoozeIntent(alarmID, custom)`)
- Bundle ID は v1 と同じ `com.example.bridgeprobe` (上書きインストール)
