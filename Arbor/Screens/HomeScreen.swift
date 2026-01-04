//
//  Home.swift
//  pytest
//

import SwiftUI

struct HomeScreen: View {
    let onDownloaded: (DownloadMeta) -> Void

    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var searchIsActive = false
    @State private var isSearching = false
    @State private var currentSearchTaskId: UUID = UUID()
    @State private var searchDebounceTimer: Timer?
    @AppStorage("homeScreenSearchProvider") var searchProvider: SearchProvider = .youtube
    @State private var selectedResult: SearchResult? = nil
    @State private var recentSearches: [RecentSearchEntry] = RecentSearchStore.load()
    @State private var pendingRecentProvider: SearchProvider? = nil

    var body: some View {
        Group {
            if searchIsActive {
                SearchResultsView(
                    searchResults: searchResults,
                    searchQuery: searchQuery,
                    isSearching: isSearching,
                    onResultSelected: { result in
                        pendingRecentProvider = searchProvider
                        selectedResult = result
                        searchIsActive = false
                        searchQuery = ""
                        searchResults = []
                        isSearching = false
                    },
                    searchProvider: $searchProvider
                )
            } else if selectedResult != nil {
                DownloadScreen(
                    onDownloaded: { meta in
                        let item = LibraryItem(meta: meta)
                        recordRecentSearch(
                            libraryItem: item,
                            provider: pendingRecentProvider ?? searchProvider
                        )
                        pendingRecentProvider = nil
                        onDownloaded(meta)
                    },
                    selectedResult: $selectedResult
                )
            } else {
                RecentSearchesView(
                    searches: recentSearches,
                    onSelect: { entry in
                        let result = SearchResult(
                            title: entry.title,
                            artists: entry.artists,
                            url: entry.originalUrl,
                            views: nil,
                            duration: nil,
                            isExplicit: nil,
                            isVerified: nil,
                            thumbnailURL: entry.thumbnailUrl,
                            thumbnailIsSquare: entry.thumbnailIsSquare,
                            thumbnailWidth: entry.thumbnailWidth,
                            thumbnailHeight: entry.thumbnailHeight
                        )
                        pendingRecentProvider = entry.provider
                        searchProvider = entry.provider
                        selectedResult = result
                        searchQuery = ""
                        searchIsActive = false
                    },
                    onClear: {
                        recentSearches = []
                        RecentSearchStore.save([])
                    }
                )
            }
        }
        .navigationTitle("arbor")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .searchable(
            text: $searchQuery,
            isPresented: $searchIsActive,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search for music"
        )
        .onSubmit(of: .search) {
            performDebouncedSearch()
        }
        .onChange(of: searchQuery) { _, newValue in
            if newValue.isEmpty {
                searchResults = []
                isSearching = false
                searchDebounceTimer?.invalidate()
                searchDebounceTimer = nil
            } else {
                performDebouncedSearch()
            }
        }
        .onChange(of: searchProvider) { _, _ in
            searchResults = []

            if !searchQuery.isEmpty {
                performDebouncedSearch()
            }
        }
        .onChange(of: searchIsActive) { _, isActive in
            if !isActive {
                searchQuery = ""
                searchResults = []
                isSearching = false
                searchDebounceTimer?.invalidate()
                searchDebounceTimer = nil
            }
        }
        .onDisappear {
            searchDebounceTimer?.invalidate()
            searchDebounceTimer = nil
        }
    }

    private func recordRecentSearch(libraryItem: LibraryItem, provider: SearchProvider) {
        let updated = RecentSearchStore.add(libraryItem: libraryItem, provider: provider, to: recentSearches)
        recentSearches = updated
        RecentSearchStore.save(updated)
    }

    private func performDebouncedSearch() {
        isSearching = true
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            performSearch()
        }
    }

    private func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        if isValidURL(trimmed) {
            searchResults = []
            isSearching = false
            return
        }

        let cacheKey = ["search", searchProvider.rawValue, trimmed.lowercased()]
        if let cached: [SearchResult] = QueryCache.shared.get(for: cacheKey) {
            searchResults = cached
            isSearching = false
            return
        }

        let taskId = UUID()
        currentSearchTaskId = taskId
        isSearching = true

        let escaped = trimmed
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        let code: String
        switch searchProvider {
        case .youtube:
            code = """
from pytest_download import search_youtube
result = search_youtube('\(escaped)')
"""
        case .soundcloud:
            code = """
from pytest_download import search_soundcloud
result = search_soundcloud('\(escaped)')
"""
        }

        pythonExecAndGetStringAsync(
            code.trimmingCharacters(in: .whitespacesAndNewlines),
            "result"
        ) { result in
            defer {
                if taskId == currentSearchTaskId {
                    isSearching = false
                }
            }

            guard let output = result, !output.isEmpty,
                  let data = output.data(using: .utf8),
                  let items = try? JSONDecoder().decode([SearchResult].self, from: data) else {
                if taskId == currentSearchTaskId {
                    searchResults = []
                }

                return
            }

            QueryCache.shared.set(items, for: cacheKey)

            if taskId == currentSearchTaskId {
                searchResults = items
            }
        }
    }
}
