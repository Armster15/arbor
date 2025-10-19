//
//  Home.swift
//  pytest
//

import SwiftUI

struct SearchResult: Decodable {
    let title: String
    let artists: [String]?
    let youtubeURL: String
    let views: String?
    let duration: String?
    let isExplicit: Bool?
    let thumbnailURL: String?
    let thumbnailIsSquare: Bool?
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case artists
        case youtubeURL = "youtube_url"
        case views
        case duration
        case isExplicit = "is_explicit"
        case thumbnailURL = "thumbnail_url"
        case thumbnailIsSquare = "thumbnail_is_square"
        case thumbnailWidth = "thumbnail_width"
        case thumbnailHeight = "thumbnail_height"
    }
}

struct HomeScreen: View {
    let canOpenPlayer: Bool
    let openPlayerAction: () -> Void
    let onDownloaded: (DownloadMeta) -> Void

    @State private var youtubeURL: String = "https://www.youtube.com/watch?v=St0s7R_qDhY"
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    @State private var searchQuery: String = ""
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
        .onChange(of: searchQuery) { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { searchResults = [] }
        }
        .searchSuggestions {
            if searchResults.isEmpty {
                Text("Try searching for a song title or artist")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(searchResults, id: \.youtubeURL) { item in
                    Button {
                        youtubeURL = item.youtubeURL
                        // Close suggestions by clearing the query and results
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        HStack(spacing: 10) {
                            // Cover art thumbnail
                            if let urlString = item.thumbnailURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack {
                                            Color.gray.opacity(0.2)
                                            ProgressView().scaleEffect(0.7)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    case .failure:
                                        ZStack {
                                            Color.gray.opacity(0.2)
                                            Image(systemName: "music.note")
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                ZStack {
                                    Color.gray.opacity(0.2)
                                    Image(systemName: "music.note")
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .lineLimit(1)
                                if let artists = item.artists {
                                    HStack(spacing: 6) {
                                        if item.isExplicit == true {
                                            Text("E")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.secondary)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                                .accessibilityLabel("Explicit")
                                        }
                                        Text(artists.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
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

    private func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        // Escape backslashes and single quotes for safe embedding in Python string literal
        let escaped = trimmed
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        let code = """
from pytest_download import search
result = search('\(escaped)')
"""

        pythonExecAndGetStringAsync(
            code.trimmingCharacters(in: .whitespacesAndNewlines),
            "result"
        ) { result in
            guard let output = result, !output.isEmpty,
                  let data = output.data(using: .utf8),
                  let items = try? JSONDecoder().decode([SearchResult].self, from: data) else {
                // silently ignore and clear suggestions on failure
                searchResults = []
                return
            }
            searchResults = items
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
