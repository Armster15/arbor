//
//  ContentView.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct ContentView: View {
    @State private var youtubeURL: String = "https://www.youtube.com/watch?v=J4kj6Ds4mrA"
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var audioPlayer: AVPlayer?
    @State private var audioFilePath: String?
    
    // AVAudioEngine properties for speed and pitch control
    @State private var engine = AVAudioEngine()
    @State private var speedControl = AVAudioUnitVarispeed()
    @State private var pitchControl = AVAudioUnitTimePitch()
    @State private var audioPlayerNode: AVAudioPlayerNode?
    @State private var currentSpeed: Float = 1.0
    @State private var currentPitch: Float = 0.0
    @State private var isPlaying: Bool = false
    @State private var manualPitch: Float = 0.0
    
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
                if let audioPath = audioFilePath, let player = audioPlayer {
                    VStack(spacing: 15) {
                        Divider()
                        
                        Text("Audio Player")
                            .font(.headline)
                        
                        // Embed AVPlayerViewController directly
                        AVPlayerViewControllerRepresentable(player: player)
                            .frame(height: 100)
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
                        
                        // Speed and Pitch Controls
                        VStack(spacing: 15) {
                            Text("Audio Controls")
                                .font(.headline)
                            
                            // Play/Pause Controls
                            HStack(spacing: 20) {
                                Button(action: togglePlayback) {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
                                }
                                
                                Button(action: stopPlayback) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Speed Control
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Speed")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(String(format: "%.2fx", currentSpeed))
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                
                                Slider(value: $currentSpeed, in: 0.1...3.0, step: 0.05)
                                    .accentColor(.blue)
                                    .onChange(of: currentSpeed) { newValue in
                                        speedControl.rate = newValue
                                        updatePitchForSpeed()
                                    }
                                
                                // Fine-tuning buttons for speed
                                HStack(spacing: 10) {
                                    Button("-0.01") {
                                        currentSpeed = max(0.1, currentSpeed - 0.01)
                                        speedControl.rate = currentSpeed
                                        updatePitchForSpeed()
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                    
                                    Button("Reset") {
                                        currentSpeed = 1.0
                                        speedControl.rate = currentSpeed
                                        updatePitchForSpeed()
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                    
                                    Button("+0.01") {
                                        currentSpeed = min(3.0, currentSpeed + 0.01)
                                        speedControl.rate = currentSpeed
                                        updatePitchForSpeed()
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                    
                                    Spacer()
                                }
                            }
                            
                            // Pitch Control
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Pitch Adjustment")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(String(format: "%.0f cents", currentPitch))
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                
                                // Show breakdown of pitch components
                                HStack {
                                    Text("Auto: \(String(format: "%.0f", getSpeedCompensation()))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("+")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Manual: \(String(format: "%.0f", manualPitch))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                Slider(value: $manualPitch, in: -2400...2400, step: 10)
                                    .accentColor(.blue)
                                    .onChange(of: manualPitch) { newValue in
                                        updateTotalPitch()
                                    }
                                
                                // Fine-tuning buttons for pitch
                                HStack(spacing: 10) {
                                    Button("-1") {
                                        manualPitch = max(-2400, manualPitch - 1)
                                        updateTotalPitch()
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                    
                                    Button("Reset") {
                                        manualPitch = 0.0
                                        updateTotalPitch()
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                    
                                    Button("+1") {
                                        manualPitch = min(2400, manualPitch + 1)
                                        updateTotalPitch()
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
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
        audioPlayer = AVPlayer(url: url)
        
        // Also setup AVAudioEngine for speed/pitch control
        setupAudioEngine(filePath: filePath)
    }
    
    private func setupAudioEngine(filePath: String) {
        do {
            // Stop and reset engine if it's running
            if engine.isRunning {
                engine.stop()
            }
            
            // Create new engine and controls
            engine = AVAudioEngine()
            speedControl = AVAudioUnitVarispeed()
            pitchControl = AVAudioUnitTimePitch()
            audioPlayerNode = AVAudioPlayerNode()
            
            // Set initial values
            speedControl.rate = currentSpeed
            pitchControl.pitch = currentPitch
            
            // Play audio using AVAudioEngine
            try playAudioWithEngine(filePath: filePath)
        } catch {
            print("Error setting up audio engine: \(error)")
        }
    }
    
    private func playAudioWithEngine(filePath: String) throws {
        let url = URL(fileURLWithPath: filePath)
        
        // 1: load the file
        let file = try AVAudioFile(forReading: url)
        
        // 2: create the audio player
        guard let audioPlayer = audioPlayerNode else { return }
        
        // 3: connect the components to our playback engine
        engine.attach(audioPlayer)
        engine.attach(pitchControl)
        engine.attach(speedControl)
        
        // 4: arrange the parts so that output from one is input to another
        engine.connect(audioPlayer, to: speedControl, format: nil)
        engine.connect(speedControl, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
        
        // 5: prepare the player to play its file from the beginning
        audioPlayer.scheduleFile(file, at: nil)
        
        // 6: start the engine and player
        try engine.start()
        audioPlayer.play()
        isPlaying = true
    }
    
    private func togglePlayback() {
        guard let audioPlayer = audioPlayerNode else { return }
        
        if isPlaying {
            audioPlayer.pause()
            isPlaying = false
        } else {
            audioPlayer.play()
            isPlaying = true
        }
    }
    
    private func stopPlayback() {
        guard let audioPlayer = audioPlayerNode else { return }
        
        audioPlayer.stop()
        isPlaying = false
        
        // Reset to beginning
        if let audioPath = audioFilePath {
            do {
                let url = URL(fileURLWithPath: audioPath)
                let file = try AVAudioFile(forReading: url)
                audioPlayer.scheduleFile(file, at: nil)
            } catch {
                print("Error resetting audio: \(error)")
            }
        }
    }
    
    private func updatePitchForSpeed() {
        // Update total pitch when speed changes (automatic compensation + manual adjustment)
        updateTotalPitch()
    }
    
    private func updateTotalPitch() {
        // Calculate total pitch: automatic speed compensation + manual adjustment
        let speedCompensation = getSpeedCompensation()
        currentPitch = speedCompensation + manualPitch
        pitchControl.pitch = currentPitch
    }
    
    private func getSpeedCompensation() -> Float {
        // Calculate pitch compensation to preserve original pitch when speed changes
        // Formula: pitch_compensation = -1200 * log2(speed)
        return Float(-1200.0 * log2(Double(currentSpeed)))
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
