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
import Foundation
import UIKit

struct ContentView: View {
    @State private var youtubeURL: String = "https://www.youtube.com/watch?v=St0s7R_qDhY"
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var audioFilePath: String?
    @StateObject private var saViewModel = SAPlayerViewModel()
	
	private struct DownloadMeta: Decodable {
		let path: String
		let title: String?
		let artist: String?
		let thumbnail_url: String?
		let thumbnail_width: Int?
		let thumbnail_height: Int?
		let thumbnail_is_square: Bool?
	}
    
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
                VStack(spacing: 15) {
                    Divider()
                                            
                    PlayerView(viewModel: saViewModel)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
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
result = download('\(youtubeURL)')
"""
        
        print("[Swift] Button tapped - starting Python execution (async)")

		pythonExecAndGetStringAsync(
            code.trimmingCharacters(in: .whitespacesAndNewlines),
            "result"
		) { result in
			defer { isLoading = false }
			guard let output = result, !output.isEmpty else {
				print("[Swift] Failed to fetch audio_fp from Python")
				showError(message: "Failed to download audio. Please check the URL and try again.")
				return
			}
			// Decode JSON metadata
			guard let data = output.data(using: .utf8),
					let meta = try? JSONDecoder().decode(DownloadMeta.self, from: data) else {
				print("[Swift] Failed to decode JSON metadata")
				showError(message: "Invalid response from downloader.")
				return
			}
			print("[Swift] Downloaded file (JSON): \(meta.path)")
			audioFilePath = meta.path
			setupAudioPlayer(filePath: meta.path)
			let artworkURL = meta.thumbnail_url.flatMap { URL(string: $0) }
			saViewModel.setMetadata(title: meta.title, artist: meta.artist, artworkURL: artworkURL)
			if let w = meta.thumbnail_width, let h = meta.thumbnail_height {
				let isSquare = abs(w - h) <= 2
				print("[Swift] Thumbnail dimensions: \(w)x\(h) | square? \(isSquare)")
			} else if let sq = meta.thumbnail_is_square {
				print("[Swift] Thumbnail square flag (from Python): \(sq)")
			}
		}
    }
    
    private func setupAudioPlayer(filePath: String) {
        // Initialize SAPlayer with saved file and attach TimePitch for speed/pitch and Reverb effect
        let timePitch = AVAudioUnitTimePitch()
        let reverb = AVAudioUnitReverb()
        reverb.wetDryMix = 0
        SAPlayer.shared.audioModifiers = [timePitch, reverb]
        saViewModel.setRate(1.0)
        saViewModel.setPitch(0.0)
        saViewModel.setReverbWetDryMix(0.0)
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
