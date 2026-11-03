# BridgeProbe

LiveContainer の「透過ブリッジ」(ゲストを改変せずに、アラームの停止・スヌーズからゲスト自身の App Intent を動かす仕組み) を検証するアプリ。

- このアプリ自身は LiveContainer のことを何も知らない普通のアプリ
- 停止 / スヌーズに自前の `LiveActivityIntent` を渡し、走れば `★` 行を記録する
- LiveContainer・ブリッジ・このアプリの 3 か所のログを、時刻順に 1 つにまとめて共有できる

使い方は [docs/検証手順.md](docs/検証手順.md)。
