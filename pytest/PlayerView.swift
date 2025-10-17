//
//  PlayerView.swift
//  pytest
//

import SwiftUI
import AVFoundation
import SwiftAudioPlayer

final class SAPlayerViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var rate: Float = 1.0
    @Published var pitch: Float = 0.0

    private var elapsedSub: UInt?
    private var durationSub: UInt?
    private var statusSub: UInt?

    func startSavedAudio(filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        SAPlayer.shared.startSavedAudio(withSavedUrl: url, mediaInfo: nil)
        subscribeUpdates()
    }

    func play() {
        SAPlayer.shared.play()
    }

    func pause() {
        SAPlayer.shared.pause()
    }

    func toggle() {
        SAPlayer.shared.togglePlayAndPause()
    }

    func seek(to seconds: Double) {
        SAPlayer.shared.seekTo(seconds: seconds)
    }

    func stop() {
        SAPlayer.shared.pause()
        SAPlayer.shared.seekTo(seconds: 0)
        isPlaying = false
        currentTime = 0
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if let node = SAPlayer.shared.audioModifiers.first as? AVAudioUnitTimePitch {
            node.rate = newRate
            SAPlayer.shared.playbackRateOfAudioChanged(rate: newRate)
        }
    }

    func setPitch(_ newPitch: Float) {
        pitch = newPitch
        if let node = SAPlayer.shared.audioModifiers.first as? AVAudioUnitTimePitch {
            node.pitch = newPitch
        }
    }

    private func subscribeUpdates() {
        if elapsedSub == nil {
            elapsedSub = SAPlayer.Updates.ElapsedTime.subscribe { [weak self] time in
                self?.currentTime = time
            }
        }
        if durationSub == nil {
            durationSub = SAPlayer.Updates.Duration.subscribe { [weak self] dur in
                self?.duration = dur
            }
        }
        if statusSub == nil {
            statusSub = SAPlayer.Updates.PlayingStatus.subscribe { [weak self] status in
                switch status {
                case .playing:
                    self?.isPlaying = true
                case .ended:
                    self?.isPlaying = false
                    SAPlayer.shared.pause()
                    SAPlayer.shared.seekTo(seconds: 0)
                    self?.currentTime = 0
                default:
                    self?.isPlaying = false
                }
            }
        }
    }

    func unsubscribeUpdates() {
        if let id = elapsedSub { SAPlayer.Updates.ElapsedTime.unsubscribe(id) }
        if let id = durationSub { SAPlayer.Updates.Duration.unsubscribe(id) }
        if let id = statusSub { SAPlayer.Updates.PlayingStatus.unsubscribe(id) }
        elapsedSub = nil
        durationSub = nil
        statusSub = nil
    }
}

struct PlayerView: View {
    @ObservedObject var viewModel: SAPlayerViewModel

    private func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "--:--" }
        let s = Int(seconds.rounded())
        let mins = s / 60
        let secs = s % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Play / Pause
            HStack(spacing: 24) {
                Button(action: { viewModel.toggle() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                Button(action: { viewModel.stop() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                }
            }

            // Scrubber
            VStack(spacing: 8) {
                GeometryReader { proxy in
                    let duration = max(viewModel.duration, 1)
                    Slider(value: Binding(get: {
                        min(viewModel.currentTime, viewModel.duration)
                    }, set: { newVal in
                        viewModel.seek(to: newVal)
                    }), in: 0...duration)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let width = max(proxy.size.width, 1)
                                let clampedX = min(max(value.location.x, 0), width)
                                let ratio = clampedX / width
                                let target = Double(ratio) * duration
                                viewModel.seek(to: target)
                            }
                    )
                }
                .frame(height: 40)

                HStack {
                    Text(formattedTime(viewModel.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formattedTime(viewModel.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Speed
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(format: "%.2fx", viewModel.rate))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                Stepper(value: Binding(get: {
                    Double(viewModel.rate)
                }, set: { newVal in
                    viewModel.setRate(Float(newVal))
                }), in: 0.25...3.0, step: 0.01) {
                    Text("Adjust speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(get: {
                    Double(viewModel.rate)
                }, set: { newVal in
                    viewModel.setRate(Float(newVal))
                }), in: 0.25...3.0, step: 0.01)
            }

            // Pitch (cents)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pitch")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(format: "%.2f cents", viewModel.pitch))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                Stepper(value: Binding(get: {
                    Double(viewModel.pitch)
                }, set: { newVal in
                    viewModel.setPitch(Float(newVal))
                }), in: -650...650, step: 1) {
                    Text("Adjust pitch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(get: {
                    Double(viewModel.pitch)
                }, set: { newVal in
                    viewModel.setPitch(Float(newVal))
                }), in: -650...650, step: 1)
            }
        }
        .padding()
        .onDisappear { viewModel.unsubscribeUpdates() }
    }
}


