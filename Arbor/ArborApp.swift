//
//  pytestApp.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import AVFoundation

@main
struct ArborApp: App {
    init() {
        _ = start_python_runtime(CommandLine.argc, CommandLine.unsafeArgv)
        // Configure audio session for stable streaming playback
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            // Prefer 44.1 kHz which matches most music services and reduces resampling
            try session.setPreferredSampleRate(44100)
            // Aim for ~1024 frames at 44.1 kHz (~23 ms) to reduce underruns
            try session.setPreferredIOBufferDuration(0.023)
            try session.setActive(true, options: [])
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
