//
//  File.swift
//  Metronome
//
//  Created by Jocelyn Griselle on 27/04/2020.
//  Copyright © 2020 Jocelyn Griselle. All rights reserved.
//

import AVFoundation
import SwiftUI
import MediaPlayer

class MetronomeAudioPlayer : ObservableObject {
    @Published var isPlaying : Bool
    @Published var isRunning : Bool
    private var engine : AVAudioEngine
    private var speedControl : AVAudioUnitVarispeed
    private var pitchControl : AVAudioUnitTimePitch
    private var playerNode : AVAudioPlayerNode
    private var audioFile : AVAudioFile
    
    init(audioFile: AVAudioFile) {
        self.audioFile = audioFile
        self.isPlaying = false
        self.isRunning = false
        self.engine = AVAudioEngine()
        self.speedControl = AVAudioUnitVarispeed()
        self.pitchControl = AVAudioUnitTimePitch()
        self.playerNode = AVAudioPlayerNode()
        setupAudioSession()
        connect()
        setupRemoteTransportControls()
        start() // should not be in init
    }
    
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func connect() {
        // connect the components to our playback engine
        engine.attach(playerNode)
        engine.attach(pitchControl)
        engine.attach(speedControl)
        // arrange the parts so that output from one is input to another
        engine.connect(playerNode, to: speedControl, format: nil)
        engine.connect(speedControl, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
    }
    
    func loadAudioFile() {
        let audioFormat = self.audioFile.processingFormat
        let audioFrameCount = UInt32(self.audioFile.length)
        let audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)
        try? self.audioFile.read(into: audioFileBuffer!)
        playerNode.scheduleBuffer(audioFileBuffer!, at: nil, options:.loops, completionHandler: nil)
        playerNode.scheduleFile(self.audioFile, at:nil)
    }
    
    
    func start() {
        try? engine.start()
        isRunning = true
        self.loadAudioFile()
    }
    
    func play() {
        if !engine.isRunning { try? engine.start() }
        playerNode.play()
        isPlaying = true
        setupNowPlaying(playing: true)
    }
    
    func pause() {
        setupNowPlaying(playing: false)
        isPlaying = false
        playerNode.pause()
        engine.pause()
    }
        
    func stop() {
        playerNode.stop()
        engine.stop()
        withAnimation {
            isPlaying = playerNode.isPlaying
            isRunning = engine.isRunning
        }
    }
    
    func setRate(rate : Float) {
        speedControl.rate = rate
    }
    
    func setPitch(rate : Float) {
        pitchControl.pitch = -1200 * (log2(rate) / log2(2))
    }
    
    func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        // Disable all buttons you will not use (including pause and togglePlayPause commands)
        [commandCenter.changeRepeatModeCommand, commandCenter.stopCommand, commandCenter.changeShuffleModeCommand, commandCenter.changePlaybackRateCommand, commandCenter.seekBackwardCommand, commandCenter.seekForwardCommand, commandCenter.skipBackwardCommand, commandCenter.skipForwardCommand, commandCenter.changePlaybackPositionCommand, commandCenter.ratingCommand, commandCenter.likeCommand, commandCenter.dislikeCommand, commandCenter.bookmarkCommand].forEach {
            $0.isEnabled = false
        }
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.play()
            return .success
            //return .commandFailed
        }
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.pause()
            return .success
            //return .commandFailed
        }
//        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
//            self.next()
//            return .success
//            //return .commandFailed
//        }
//        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
//            self.previous()
//            return .success
//            //return .commandFailed
//        }
    }
    
    func elapsedPlaybackTime() -> Double {
        guard let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return 0.0
        }
        return Double(TimeInterval(playerTime.sampleTime) / playerTime.sampleRate)
    }
    
//    func loadArtwork(from url: URL) async -> MPMediaItemArtwork? {
//        do {
//            let (data, _) = try await URLSession.shared.data(from: url)
//            if let image = UIImage(data: data) {
//                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
//                    return image
//                }
//            }
//        }
//        catch {
//            return nil
//        }
//    }

        
    func setupNowPlaying(playing:Bool=false) {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Hello World"
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Artist"
        
//        Task {
//            var url = URL(string: "https://lh3.googleusercontent.com/4V1E0_riSFNKo2CqhBVyiVDTxKDctrpRY4TdoK_shvu_rOlrtwYn1NISnukUkarizgEFK1lfsDiSCpKH=w544-h544-l90-rj")
//            let img = await self.loadArtwork(from: url!)
//            nowPlayingInfo[MPMediaItemPropertyArtwork] = img
//        }
        
//        let elapsed = elapsedPlaybackTime()
//        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
//        let audioNodeFileLength = AVAudioFrameCount(self.genre.loop.length)
//        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(Double(audioNodeFileLength) / 44100)
//        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] = elapsed
//            / Double(Double(audioNodeFileLength) / 44100)
//        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = NSNumber(value:1.0)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: playing ? speedControl.rate : 0.0)
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
        
        print("PLAYING: \(playing)")
        print(nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as Any)
        print(nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] as Any)
        print(nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as Any
        )
        print(nowPlayingInfoCenter.playbackState.rawValue)
        print("END")
        
    }
}
