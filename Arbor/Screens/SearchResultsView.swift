import SwiftUI

struct SearchResultsView: View {
    let searchResults: [SearchResult]
    let searchQuery: String
    let isSearching: Bool
    let onResultSelected: (SearchResult) -> Void
    @Binding var searchProvider: SearchProvider
    @State private var searchVisible: Bool = false

    var body: some View {
        let isSearchQueryURL = isValidURL(searchQuery)

        VStack(spacing: 0) {
            Picker("Provider", selection: $searchProvider) {
                Text(SearchProvider.youtube.displayName).tag(SearchProvider.youtube)
                Text(SearchProvider.soundcloud.displayName).tag(SearchProvider.soundcloud)
            }
            .pickerStyle(.segmented)
            .disabled(isSearchQueryURL)
            .padding()
            .opacity(searchVisible ? 1 : 0)
            .offset(y: searchVisible ? 0 : -8)
            .animation(.easeInOut(duration: 0.28), value: searchVisible)

            if searchQuery.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Search for a song or artist")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSearchQueryURL {
                VStack(spacing: 16) {
                    let result = SearchResult(
                        title: searchQuery,
                        artists: ["Raw URL"],
                        url: searchQuery,
                        views: nil,
                        duration: nil,
                        isExplicit: nil,
                        isVerified: nil,
                        thumbnailURL: nil,
                        thumbnailIsSquare: nil,
                        thumbnailWidth: nil,
                        thumbnailHeight: nil
                    )

                    SearchResultRow(result: result) {
                        onResultSelected(result)
                    }
                }
                .padding(.bottom, 16)
            } else if isSearching && searchResults.isEmpty {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                        .accessibilityLabel("Searching...")

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No results found")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("Try searching for a song title or artist")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults, id: \.url) { result in
                            SearchResultRow(result: result) {
                                onResultSelected(result)
                            }

                            if result != searchResults.last {
                                Divider()
                                    .padding(.leading, 74)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 0)
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            searchVisible = true
        }
        .onDisappear {
            searchVisible = false
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                SongImage(
                    width: 50,
                    height: 50,
                    thumbnailURL: result.thumbnailURL,
                    thumbnailIsSquare: result.thumbnailIsSquare
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        if result.isExplicit == true {
                            Text("E")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .accessibilityLabel("Explicit")
                        }

                        HStack(spacing: 4) {
                            Text(formatArtists(result.artists))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            if result.isVerified == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .accessibilityLabel("Verified artist")
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        if let duration = result.duration {
                            Text(duration)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if let views = result.views {
                            HStack(spacing: 2) {
                                Image(systemName: "eye")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(views)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
}
