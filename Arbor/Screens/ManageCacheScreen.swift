import SwiftUI
import SPIndicator

struct ManageCacheScreen: View {
    private let tmpPath = NSTemporaryDirectory()
    @State private var sizeBytes: Int64?
    @State private var isLoading = false
    @State private var isClearing = false
    @State private var showClearConfirm = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Temporary files")
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
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Text("Delete Temporary Files")
                }
                .disabled(isClearing)
                .listRowBackground(Color("SecondaryBg"))
            }
        }
        .scrollContentBackground(.hidden)
        .task {
            refreshSize()
        }
        .confirmationDialog(
            "Delete temporary files?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                clearTempFiles()
            }
        }
    }

    private func refreshSize() {
        isLoading = true
        Task.detached {
            let size = Self.directorySize(at: tmpPath)
            await MainActor.run {
                sizeBytes = size
                isLoading = false
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
                    try? FileManager.default.removeItem(at: item)
                }
                let size = Self.directorySize(at: tmpPath)
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

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private static func directorySize(at path: String) -> Int64 {
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
