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
    
    init() {
        _ = start_python_runtime(CommandLine.argc, CommandLine.unsafeArgv)
        SyncMonitor.default.startMonitoring()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
        }
        .modelContainer(for: [LibraryItem.self])
    }
}
