//
//  ContentView.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var youtubeURL: String = "https://www.youtube.com/watch?v=J4kj6Ds4mrA"
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioFilePath: String?
    @State private var isPlaying: Bool = false
    
    var body: some View {
        NavigationView {
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
                        
                        Text("Downloaded Audio")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            Button(action: togglePlayback) {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Audio File")
                                    .font(.headline)
                                Text(audioPath.components(separatedBy: "/").last ?? "Unknown")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
            .padding()
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
        
        let code = """
from pytest_download import download
audio_fp = download('\(youtubeURL)')
"""
        
        print("[Swift] Button tapped - starting Python execution")
        print("[Swift] Running Python execution on main thread")
        
        if let audioPath = pythonExecAndGetString(
            code.trimmingCharacters(in: .whitespacesAndNewlines), 
            "audio_fp"
        ) {
            print("[Swift] Downloaded file: \(audioPath)")
            audioFilePath = audioPath
            setupAudioPlayer(filePath: audioPath)
        } else {
            print("[Swift] Failed to fetch audio_fp from Python")
            showError(message: "Failed to download audio. Please check the URL and try again.")
        }
        
        isLoading = false
    }
    
    private func setupAudioPlayer(filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Error setting up audio player: \(error)")
            showError(message: "Failed to load audio file for playback")
        }
    }
    
    private func togglePlayback() {
        guard let player = audioPlayer else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        
        isPlaying.toggle()
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

#Preview {
    ContentView()
}
