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
    private let modelContainer: ModelContainer
    
    init() {
        _ = start_python_runtime(CommandLine.argc, CommandLine.unsafeArgv)
        SyncMonitor.default.startMonitoring()
        do {
            modelContainer = try ModelContainer(for: LibraryItem.self, migrationPlan: ArborMigrationPlan.self)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(lastFM)
        }
        .modelContainer(modelContainer)
    }
}
