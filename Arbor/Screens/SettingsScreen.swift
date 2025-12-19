//
//  SettingsScreen.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 12/2/25.
//


import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        List {
            NavigationLink {
                LastFMIntegrationScreen()
                    .background(BackgroundColor.ignoresSafeArea(.all))
            } label: {
                IntegrationRow(
                    title: "last.fm",
                    subtitle: "Connect to start scrobbling"
                )
            }
            .listRowBackground(Color("SecondaryBg"))
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
    }
}

private struct IntegrationRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("LastFM")
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color("PrimaryText"))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(Color("PrimaryText").opacity(0.8))
                    .lineLimit(2)
            }
        }
    }
}

private struct LastFMIntegrationScreen: View {
    var body: some View {
        ZStack {
            Text("Last.fm")
                .foregroundStyle(Color("PrimaryText"))
        }
        .navigationTitle("last.fm")
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
