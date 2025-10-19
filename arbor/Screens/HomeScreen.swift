//
//  Home.swift
//  pytest
//

import SwiftUI
import UIKit

struct HomeScreen: View {
    let canOpenPlayer: Bool
    let openPlayerAction: () -> Void
    let onDownloaded: (DownloadMeta) -> Void

    @State private var youtubeURL: String = "https://www.youtube.com/watch?v=St0s7R_qDhY"
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // Search UI state (UI only – no fetching logic)
    private struct SearchResult: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let channel: String
        let duration: String
        let url: String
    }

    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [SearchResult] = []

    var body: some View {
        VStack(spacing: 20) {

            // URL Input Section
            VStack(alignment: .leading, spacing: 8) {
                Text("YouTube URL")
                    .font(.headline)

                TextField("Enter YouTube URL", text: $youtubeURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .disabled(isLoading)
                    .padding(.trailing, 36)
                    .overlay(alignment: .trailing) {
                        Button(action: {
                            if let clipboard = UIPasteboard.general.string {
                                youtubeURL = clipboard
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.secondary)
                        }
                        .padding(.trailing, 8)
                        .accessibilityLabel("Paste from clipboard")
                    }
                    // select all text when text field is focused
                    // https://stackoverflow.com/a/67502495
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }
            }

            // Download Button
            Button(action: downloadAudio) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }

                    Text(isLoading ? "Downloading..." : "Download Audio")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isLoading ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)

            if canOpenPlayer {
                // Player Screen Navigation Trigger
                VStack(spacing: 15) {
                    Divider()
                    Button(action: openPlayerAction) {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                            Text("Open Player")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("🌳 Arbor")
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search by title, artist, etc.")
        .onSubmit(of: .search) {
            performSearch()
        }
        .searchSuggestions {
            // Show suggestions based on current query and existing demo results
            if isSearching {
                Label("Searching…", systemImage: "hourglass")
                    .foregroundColor(.secondary)
            } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Starter suggestions (static)
                ForEach(["faded", "lofi", "chill beats", "instrumental"], id: \.self) { suggestion in
                    Text(suggestion)
                        .searchCompletion(suggestion)
                }
            } else if !searchResults.isEmpty {
                ForEach(searchResults) { result in
                    // Tapping a suggestion fills the search field; selecting from results still fills URL below
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                            .searchCompletion(result.title)
                        Text("\(result.channel) • \(result.duration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        youtubeURL = result.url
                    }
                }
            }
        }
        .alert("Download Failed", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func downloadAudio() {
        let trimmed = youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showError(message: "Please enter a YouTube URL")
            return
        }

        isLoading = true
        
        // this is not the best way to do this but it works for now
        // how we should actually do it: see https://docs.python.org/3/extending/embedding.html
        // tldr: import module and invoke function with args directly via obj-c. they have utils
        // for importing, invoking methods, passing args, etc.
        let code = """
from pytest_download import download
result = download('\(trimmed)')
"""

        pythonExecAndGetStringAsync(
            code.trimmingCharacters(in: .whitespacesAndNewlines),
            "result"
        ) { result in
            defer { isLoading = false }
            guard let output = result, !output.isEmpty else {
                showError(message: "Failed to download audio. Please check the URL and try again.")
                return
            }
            guard let data = output.data(using: .utf8),
                let meta = try? JSONDecoder().decode(DownloadMeta.self, from: data) else {
                    showError(message: "Invalid response from downloader.")
                    return
                }
                onDownloaded(meta)
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    // UI-only search that generates placeholder results based on the query
    private func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        // Simulate a brief search delay for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let baseTitles = [
                "\(trimmed)",
                "\(trimmed) (Official Video)",
                "\(trimmed) (Lyrics)",
                "\(trimmed) (Audio)",
                "\(trimmed) Live",
                "\(trimmed) Remix"
            ]

            let channels = ["Artist Channel", "Topic", "Vevo", "Official", "Live Archive", "Mixes"]
            let durations = ["3:12", "3:45", "4:02", "2:58", "5:21", "3:33"]

            searchResults = baseTitles.enumerated().map { idx, title in
                SearchResult(
                    title: title,
                    channel: channels[idx % channels.count],
                    duration: durations[idx % durations.count],
                    // Placeholder URL per result; selecting will fill the URL field
                    url: "https://www.youtube.com/watch?v=placeholder_\(idx + 1)"
                )
            }
            isSearching = false
        }
    }
}
