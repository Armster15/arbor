//
//  ContentView.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import AVFoundation
import AVKit
import SwiftAudioPlayer

struct ContentView: View {
    @State private var youtubeURL: String = "https://www.youtube.com/watch?v=St0s7R_qDhY"
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var audioFilePath: String?
    @StateObject private var saViewModel = SAPlayerViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                // Header
                VStack {
                    Image(systemName: "music.note")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("YouTube Audio Downloader")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Download and play audio from YouTube videos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // URL Input Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("YouTube URL")
                        .font(.headline)
                    
                    TextField("Enter YouTube URL", text: $youtubeURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
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
                
                // Audio Player Section
                if let audioPath = audioFilePath {
                    VStack(spacing: 15) {
                        Divider()
                        
                        Text("Audio Player")
                            .font(.headline)
                        
                        PlayerView(viewModel: saViewModel)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        // File info
                        VStack(spacing: 4) {
                            Text("Audio File")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(audioPath.components(separatedBy: "/").last ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // Controls moved into PlayerView via SAPlayer
                    }
                }
                
                }
                .padding()
            }
            .navigationTitle("Audio Downloader")
            .alert("Download Failed", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func downloadAudio() {
        guard !youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
audio_fp = download('\(youtubeURL)')
"""
        
        print("[Swift] Button tapped - starting Python execution (async)")

        pythonExecAndGetStringAsync(
            code.trimmingCharacters(in: .whitespacesAndNewlines),
            "audio_fp"
        ) { result in
            if let audioPath = result, !audioPath.isEmpty {
                print("[Swift] Downloaded file: \(audioPath)")
                audioFilePath = audioPath
                setupAudioPlayer(filePath: audioPath)
            } else {
                print("[Swift] Failed to fetch audio_fp from Python")
                showError(message: "Failed to download audio. Please check the URL and try again.")
            }

            isLoading = false
        }
    }
    
    private func setupAudioPlayer(filePath: String) {
        // Initialize SAPlayer with saved file and attach TimePitch for speed/pitch
        let timePitch = AVAudioUnitTimePitch()
        SAPlayer.shared.audioModifiers = [timePitch]
        saViewModel.setRate(1.0)
        saViewModel.setPitch(0.0)
        saViewModel.startSavedAudio(filePath: filePath)
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        
        // Configure for audio-only playback
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = false
        
        // Hide video content area for audio-only
        controller.videoGravity = .resizeAspect
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

#Preview {
    ContentView()
}
