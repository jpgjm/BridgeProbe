//
//  BridgeProbeApp.swift
//  BridgeProbe
//
//  LiveContainer の透過ブリッジ (TweakLoader/AlarmKitBridge.m) を検証するアプリ。
//  このアプリは LiveContainer のことを何も知らない「普通のアプリ」として書く。
//  ゲスト側の改変なしで、自分の Intent がアラームのボタンから動くかを確かめる。
//

import SwiftUI

@main
struct BridgeProbeApp: App {

    init() {
        AppLog.info("app", "起動 環境=\(Env.label) version=\(Env.appVersion)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
