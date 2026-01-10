import SwiftUI
import SPIndicator

struct ManageCacheScreen: View {
    private let tmpPath = NSTemporaryDirectory()
    private let lyricsCachePath = LyricsCache.cacheDirectoryPath()
    @State private var sizeBytes: Int64?
    @State private var lyricsSizeBytes: Int64?
    @State private var isLoading = false
    @State private var isLyricsLoading = false
    @State private var isClearing = false
    @State private var isClearingLyrics = false
    @State private var showClearConfirm = false
    @State private var showClearLyricsConfirm = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Temporary Files")
                        .foregroundColor(Color("PrimaryText"))

                    Spacer()

                    if let sizeBytes {
                        Text(formatBytes(sizeBytes))
                            .foregroundColor(Color("PrimaryText").opacity(0.8))
                    } else if isLoading {
                        ProgressView()
                    } else {
                        Text("Unknown")
                            .foregroundColor(Color("PrimaryText").opacity(0.8))
                    }
                }
                .listRowBackground(Color("SecondaryBg"))

                HStack {
                    Text("Lyrics Cache")
                        .foregroundColor(Color("PrimaryText"))

                    Spacer()

                    if let lyricsSizeBytes {
                        Text(formatBytes(lyricsSizeBytes))
                            .foregroundColor(Color("PrimaryText").opacity(0.8))
                    } else if isLyricsLoading {
                        ProgressView()
                    } else {
                        Text("Unknown")
                            .foregroundColor(Color("PrimaryText").opacity(0.8))
                    }
                }
                .listRowBackground(Color("SecondaryBg"))
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Text("Delete Temporary Files")
                }
                .disabled(isClearing)
                .listRowBackground(Color("SecondaryBg"))

                Button(role: .destructive) {
                    showClearLyricsConfirm = true
                } label: {
                    Text("Delete Lyrics Cache")
                }
                .disabled(isClearingLyrics)
                .listRowBackground(Color("SecondaryBg"))
            }
        }
        .scrollContentBackground(.hidden)
        .task {
            refreshSizes()
        }
        .confirmationDialog(
            "Delete Temporary Files?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                clearTempFiles()
            }
        }
        .confirmationDialog(
            "Delete Lyrics Cache?",
            isPresented: $showClearLyricsConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                clearLyricsCache()
            }
        }
    }

    private func refreshSizes() {
        isLoading = true
        isLyricsLoading = true
        Task.detached {
            let size = Self.directorySize(at: tmpPath, excludingPath: lyricsCachePath)
            let lyricsSize = lyricsCachePath.map { Self.directorySize(at: $0) }
            await MainActor.run {
                sizeBytes = size
                isLoading = false
                lyricsSizeBytes = lyricsSize
                isLyricsLoading = false
            }
        }
    }

    private func clearTempFiles() {
        isClearing = true
        Task.detached {
            do {
                let dirURL = URL(fileURLWithPath: tmpPath, isDirectory: true)
                let contents = try FileManager.default.contentsOfDirectory(
                    at: dirURL,
                    includingPropertiesForKeys: nil
                )
                for item in contents {
                    if let lyricsCachePath,
                       item.path == lyricsCachePath {
                        continue
                    }
                    try? FileManager.default.removeItem(at: item)
                }
                let size = Self.directorySize(at: tmpPath, excludingPath: lyricsCachePath)
                await MainActor.run {
                    sizeBytes = size
                    isClearing = false
                    SPIndicatorView(title: "Cache cleared", preset: .done).present()
                }
            } catch {
                await MainActor.run {
                    isClearing = false
                    SPIndicatorView(
                        title: "Failed to clear cache",
                        message: error.localizedDescription,
                        preset: .error
                    ).present()
                }
            }
        }
    }

    private func clearLyricsCache() {
        isClearingLyrics = true
        Task.detached {
            LyricsCache.shared.clearAll()
            let size = lyricsCachePath.map { Self.directorySize(at: $0) }
            await MainActor.run {
                lyricsSizeBytes = size
                isClearingLyrics = false
                SPIndicatorView(title: "Lyrics cache cleared", preset: .done).present()
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private static func directorySize(at path: String, excludingPath: String? = nil) -> Int64 {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let excludingPath,
               fileURL.path.hasPrefix(excludingPath) {
                continue
            }
            do {
                let values = try fileURL.resourceValues(forKeys: resourceKeys)
                if values.isRegularFile == true {
                    total += Int64(values.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }

        return total
    }
}
