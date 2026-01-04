import SwiftUI

struct DownloadScreen: View {
    let onDownloaded: (DownloadMeta) -> Void
    @Binding var selectedResult: SearchResult?

    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ZStack {
                    VStack(spacing: 32) {
                        if let result = selectedResult {
                            SongInfo(
                                title: result.title,
                                artists: result.artists,
                                thumbnailURL: result.thumbnailURL,
                                thumbnailIsSquare: result.thumbnailIsSquare
                            )
                        }

                        HStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                                .accessibilityLabel("Downloading...")
                            Text("Downloading...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .onAppear {
            triggerDownloadIfPossible()
        }
        .onChange(of: selectedResult?.url) { _, _ in
            triggerDownloadIfPossible()
        }
    }

    private func triggerDownloadIfPossible() {
        guard !isLoading, let url = selectedResult?.url else { return }
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        downloadAudio(with: trimmed)
    }
    
    private func downloadAudio(with url: String) {
        if let localResult = AudioDownloader.localAudioMeta(from: url, searchResult: selectedResult) {
            handleDownloadResult(localResult)
            return
        }

        isLoading = true

        AudioDownloader.downloadFromPython(from: url) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                self.handleDownloadResult(result)
            }
        }
    }

    private func handleDownloadResult(_ result: Result<DownloadMeta, Error>) {
        switch result {
        case .success(let meta):
            onDownloaded(meta)
            selectedResult = nil

        case .failure(let error):
            let message: String

            if let downloadError = error as? DownloadError {
                switch downloadError {
                case .invalidSelection:
                    message = "Invalid selection"
                case .emptyResult:
                    message = "Failed to download audio. Please check the URL and try again."
                case .invalidResponse:
                    message = "Invalid response from downloader."
                }
            } else {
                message = "Failed to download audio. Please check the URL and try again."
            }

            onError(message: message)
        }
    }

    private func onError(message: String) {
        showAlert(title: "Download Failed", message: message)
    }
}
