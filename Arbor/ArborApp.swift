//
//  pytestApp.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import SwiftData
import CloudKitSyncMonitor

@main
struct ArborApp: App {
    @StateObject private var player = PlayerCoordinator()
    @StateObject private var lastFM = LastFMSession()
    
    init() {
        _ = start_python_runtime(CommandLine.argc, CommandLine.unsafeArgv)
        SyncMonitor.default.startMonitoring()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(lastFM)
        }
        .modelContainer(for: [LibraryItem.self])
    }
}
