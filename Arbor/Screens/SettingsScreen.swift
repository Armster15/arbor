//
//  SettingsScreen.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 12/2/25.
//


import SwiftUI
import CloudKitSyncMonitor

struct SettingsScreen: View {
    @StateObject private var syncMonitor = SyncMonitor.default

    var body: some View {
        List {
            Section {
                SyncStatusRow(syncMonitor: syncMonitor)
                    .listRowBackground(Color("SecondaryBg"))
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
    }
}

private struct SyncStatusRow: View {
    @ObservedObject var syncMonitor: SyncMonitor

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: syncMonitor.syncStateSummary.symbolName)
                .font(.title2)
                .foregroundColor(syncMonitor.syncStateSummary.symbolColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("iCloud Sync")
                    .font(.headline)
                    .foregroundColor(Color("PrimaryText"))

                Text(syncMonitor.syncStateSummary.description)
                    .font(.subheadline)
                    .foregroundColor(Color("PrimaryText").opacity(0.8))
            }

            Spacer()

            if syncMonitor.syncStateSummary.isInProgress {
                ProgressView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ZStack {
            BackgroundColor.ignoresSafeArea()
            SettingsScreen()
        }
    }
}
