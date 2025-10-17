//
//  pytestApp.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import AVFoundation

@main
struct pytestApp: App {
    init() {
        _ = start_python_runtime(CommandLine.argc, CommandLine.unsafeArgv)
            configureAudioSession()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

        private func configureAudioSession() {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .duckOthers])
                try session.setActive(true)
            } catch {
                print("[AudioSession] Failed to configure: \(error)")
            }
        }
}
