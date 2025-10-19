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
}
