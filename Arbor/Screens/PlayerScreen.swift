//
//  PlayerView.swift
//  pytest
//

import SwiftUI
import Foundation
import SwiftData
import SDWebImage
import SDWebImageSwiftUI
import UIKit

// this is so we can provide the actual PlayerScreen (__PlayerScreen)
// with non-nullable values for libraryItem, audioPlayer, and filePath
struct PlayerScreen: View {
    @EnvironmentObject var player: PlayerCoordinator
        
    var body: some View {
        Group {
            if let libraryItem = player.libraryItem,
               let audioPlayer = player.audioPlayer,
               let filePath = player.filePath {
                __PlayerScreen(
                    libraryItem: libraryItem,
                    audioPlayer: audioPlayer,
                    filePath: Binding(
                        get: { filePath },
                        set: { player.filePath = $0 }
                    )
                )
            } else {
                EmptyView()
            }
        }
    }
}

struct __PlayerScreen: View {
    @Bindable var libraryItem: LibraryItem
    @ObservedObject var audioPlayer: AudioPlayerWithReverb
    @Binding var filePath: String
    
    @State private var isEditSheetPresented: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftArtists: [String] = []
    @State private var isScrubbing: Bool = false
    @State private var scrubberTime: Double = 0
    @State private var editSheetHeight: CGFloat = 0
    @State private var editSheetContentHeight: CGFloat = 0
    @State private var editSheetButtonHeight: CGFloat = 0
    @State private var lyricsState: LyricsState = .idle
    @State private var currentLyricsTaskId: UUID?
    @State private var lastActiveLyricIndex: Int?
    @State private var romanizedLyricLines: [String]?
    @State private var translatedLyricLines: [String]?
    @State private var isTranslatingLyrics: Bool = false
    @State private var lyricsDisplayMode: LyricsDisplayMode = .original
    @State private var currentTranslateTaskId: UUID?
    
    // Track last saved settings locally (not persisted to iCloud)
    @State private var savedSpeedRate: Float?
    @State private var savedPitchCents: Float?
    @State private var savedReverbMix: Float?

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext

    private enum LyricsState: Equatable {
        case idle
        case loading
        case loaded(LyricsPayload)
        case empty
        case failed
    }

    private enum LyricsDisplayMode: String, CaseIterable {
        case original = "Original"
        case romanized = "Romanized"
        case translated = "Translated"
    }

    private struct SheetHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    private struct SheetButtonHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    private var editSheetDetentHeight: CGFloat {
        let maxSheetHeight = UIScreen.main.bounds.height * 0.9
        let targetHeight = editSheetContentHeight + editSheetButtonHeight
        return min(max(targetHeight, 280), maxSheetHeight)
    }
    
    private var isDownloaded: Bool {
        getLocalAudioFilePath(originalUrl: libraryItem.original_url) != nil
    }
    
    private var isModified: Bool {
        let refSpeed = savedSpeedRate ?? libraryItem.speedRate
        let refPitch = savedPitchCents ?? libraryItem.pitchCents
        let refReverb = savedReverbMix ?? libraryItem.reverbMix
        
        return audioPlayer.speedRate != refSpeed ||
               audioPlayer.pitchCents != refPitch ||
               audioPlayer.reverbMix != refReverb
    }
    
    init(libraryItem: LibraryItem, audioPlayer: AudioPlayerWithReverb, filePath: Binding<String>) {
        self.libraryItem = libraryItem
        self.audioPlayer = audioPlayer
        self._filePath = filePath
    }

    private func decoratedTitle() -> String {
        var tags: [String] = []
        if audioPlayer.speedRate > 1.0 {
            tags.append("sped up")
        } else if audioPlayer.speedRate < 1.0 {
            tags.append("slowed")
        }
        if audioPlayer.reverbMix > 0.0 {
            if tags.isEmpty {
                tags.append("reverb")
            } else {
                tags.append("reverb")
            }
        }
        guard !tags.isEmpty else { return libraryItem.title }
        return "\(libraryItem.title) (\(tags.joined(separator: " + ")))"
    }

    private func fetchLyricsIfNeeded() {
        let taskId = UUID()
        currentLyricsTaskId = taskId
        lyricsState = .loading
        romanizedLyricLines = nil
        translatedLyricLines = nil
        lyricsDisplayMode = .original
        isTranslatingLyrics = false
        currentTranslateTaskId = nil

        LyricsCache.shared.fetchLyrics(originalUrl: libraryItem.original_url) { result in
            guard taskId == currentLyricsTaskId else { return }

            switch result {
            case .loaded(let payload):
                lyricsState = .loaded(payload)
            case .empty:
                lyricsState = .empty
            case .failed:
                lyricsState = .failed
            }
        }
    }

    private func translateLyrics(payload: LyricsPayload) {
        guard !isTranslatingLyrics else { return }
        isTranslatingLyrics = true
        let taskId = UUID()
        currentTranslateTaskId = taskId
        LyricsCache.shared.translateLyrics(originalUrl: libraryItem.original_url, payload: payload) { result in
            guard taskId == currentTranslateTaskId else { return }
            isTranslatingLyrics = false

            switch result {
            case .loaded(let translationPayload):
                romanizedLyricLines = translationPayload.romanizations
                translatedLyricLines = translationPayload.translations
            case .failed:
                break
            }
        }
    }

    private func scrollToActiveLyric(
        _ proxy: ScrollViewProxy,
        activeIndex: Int?,
        shouldAnimate: Bool
    ) {
        guard let activeIndex else { return }
        lastActiveLyricIndex = activeIndex
        if shouldAnimate {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(activeIndex, anchor: .center)
            }
        } else {
            proxy.scrollTo(activeIndex, anchor: .center)
        }
    }

    private var lyricsSection: some View {
        Group {
            if case .loaded(let payload) = lyricsState, !payload.lines.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Lyrics")
                            .font(.headline)
                            .foregroundColor(Color("PrimaryText"))

                        Spacer()

                        if isTranslatingLyrics {
                            ProgressView()
                                .scaleEffect(0.7)
                        }

                        Menu {
                            ForEach(LyricsDisplayMode.allCases, id: \.self) { mode in
                                Button {
                                    lyricsDisplayMode = mode
                                } label: {
                                    Label(
                                        mode.rawValue,
                                        systemImage: lyricsDisplayMode == mode ? "checkmark" : ""
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "translate")
                                .font(.callout)
                                .foregroundColor(lyricsDisplayMode != .original && !isTranslatingLyrics ? .blue : Color("PrimaryText"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(colorScheme == .light ? Color("Elevated") : Color("SecondaryBg"))
                                .clipShape(Capsule())
                        }
                        .disabled(isTranslatingLyrics)
                    }

                    let currentMs = Int(audioPlayer.currentTime * 1000)
                    let activeIndex = LyricsCache.activeLyricIndex(
                        for: payload,
                        currentTimeMs: currentMs
                    )
                    let selectedLyricLines: [String]? = {
                        switch lyricsDisplayMode {
                        case .original:
                            return nil
                        case .romanized:
                            return romanizedLyricLines
                        case .translated:
                            return translatedLyricLines
                        }
                    }()
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(payload.lines.indices, id: \.self) { index in
                                    let line = payload.lines[index]
                                    let isActive = payload.timed && index == activeIndex
                                    let displayText = selectedLyricLines?[index] ?? line.text
                                    if payload.timed {
                                        HStack(alignment: .top, spacing: 12) {
                                            Text(displayText.isEmpty ? " " : displayText)
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(
                                                    isActive ? Color("PrimaryText") : Color("PrimaryText").opacity(0.1)
                                                )
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .animation(.easeInOut(duration: 0.15), value: isActive)
                                        }
                                        .id(index)
                                    } else {
                                        Text(displayText.isEmpty ? " " : displayText)
                                            .font(.body)
                                            .foregroundColor(Color("PrimaryText"))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id(index)
                                    }
                                }
                            }
                            .lineSpacing(4)
                            .padding(.vertical, 8)
                        }
                        .scrollDisabled(true)
                        .frame(maxHeight: 260)
                        .scrollIndicators(.hidden)
                        .onChange(of: activeIndex) { _, newValue in
                            guard let newValue, newValue != lastActiveLyricIndex else { return }
                            scrollToActiveLyric(proxy, activeIndex: newValue, shouldAnimate: true)
                        }
                        .onChange(of: lyricsDisplayMode) { _, newValue in
                            if newValue == .romanized || newValue == .translated {
                                if romanizedLyricLines == nil || translatedLyricLines == nil {
                                    translateLyrics(payload: payload)
                                }
                            }
                            DispatchQueue.main.async {
                                scrollToActiveLyric(proxy, activeIndex: activeIndex, shouldAnimate: false)
                            }
                        }
                        .onChange(of: romanizedLyricLines) { _, _ in
                            DispatchQueue.main.async {
                                scrollToActiveLyric(proxy, activeIndex: activeIndex, shouldAnimate: false)
                            }
                        }
                        .onChange(of: translatedLyricLines) { _, _ in
                            DispatchQueue.main.async {
                                scrollToActiveLyric(proxy, activeIndex: activeIndex, shouldAnimate: false)
                            }
                        }
                        // scroll to the active lyric on appear (e.g. when player is reopened)
                        .onAppear {
                            scrollToActiveLyric(proxy, activeIndex: activeIndex, shouldAnimate: false)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("SecondaryBg"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.35), value: lyricsState)
    }
    
    private func saveToLibrary() {
        let SHOULD_COPY = true

        // if SHOULD_COPY is true, it will save a new library item
        // else if false it will edit the existing library item
        let item = SHOULD_COPY ? LibraryItem(copyOf: libraryItem) : libraryItem
        
        item.speedRate = audioPlayer.speedRate
        item.pitchCents = audioPlayer.pitchCents
        item.reverbMix = audioPlayer.reverbMix
        
        let originalUrl = item.original_url
        
        let absolutePath = ensureLocalAudioFile(
            originalUrl: originalUrl,
            sourcePath: filePath,
            title: item.title,
            artists: item.artists,
            onMissingPhysicalFile: {
                debugPrint("Deleting outdated library item: \(item.title)")
                modelContext.delete(item)
            }
        )
        
        self.filePath = absolutePath
        
        if SHOULD_COPY {
            modelContext.insert(item)
        }
        
        // Track saved settings locally so isModified reflects the saved state
        savedSpeedRate = audioPlayer.speedRate
        savedPitchCents = audioPlayer.pitchCents
        savedReverbMix = audioPlayer.reverbMix
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    SongInfo(
                        title: libraryItem.title,
                        artists: libraryItem.artists,
                        thumbnailURL: libraryItem.thumbnail_url,
                        thumbnailIsSquare: libraryItem.thumbnail_is_square,
                        thumbnailForceSquare: false,
                        thumbnailHasContextMenu: true
                    )
                                        
                    // Action buttons
                    ZStack {
                        // Centered main controls
                        HStack(spacing: 16) {
                            // Rewind
                            Button(action: {
                                audioPlayer.seek(to: 0)
                                
                            }) {
                                Image(systemName: "backward.end.circle.fill")
                                    .font(.system(size: 44))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(
                                        Color("PrimaryText"),
                                        Color("SecondaryBg")
                                    )
                            }
                            
                            // Play / Pause
                            Button(action: {
                                if audioPlayer.isPlaying {
                                    audioPlayer.pause()
                                } else {
                                    audioPlayer.play()
                                }
                            }) {
                                Image(
                                    systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                                )
                                .font(.system(size: 56))
                                .foregroundColor(Color("PrimaryBg"))
                            }
                            
                            // Stop
                            Button(action: {
                                audioPlayer.stop()
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(
                                        Color("PrimaryText"),
                                        Color("SecondaryBg")
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Trailing loop button
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                audioPlayer.toggleLoop()
                            }) {
                                Image(
                                    systemName: audioPlayer.isLooping ? "repeat.1.circle.fill" : "repeat.circle.fill"
                                )
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    Color("PrimaryText").opacity(0.8),
                                    // TODO: abstract away as a secondary smth color
                                    .clear
                                )
                                .accessibilityLabel(
                                    audioPlayer.isLooping ? "Disable Loop" : "Enable Loop"
                                )
                            }
                        }
                    }
                    
                    // Scrubber
                    Scrubber(
                        value: $scrubberTime,
                        inRange: 0...max(audioPlayer.duration, 0.01),
                        activeFillColor: Color("PrimaryBg"),
                        fillColor: Color("PrimaryBg").opacity(0.8),
                        emptyColor: Color("PrimaryBg").opacity(0.2),
                        height: 30,
                        onEditingChanged: { editing in
                            isScrubbing = editing
                            if editing {
                                scrubberTime = audioPlayer.currentTime
                            }
                            if !editing {
                                audioPlayer.seek(to: scrubberTime)
                            }
                        }
                    )
                    .onChange(of: audioPlayer.currentTime) { _, newValue in
                        guard !isScrubbing else { return }
                        scrubberTime = newValue
                    }
                    .onAppear {
                        scrubberTime = audioPlayer.currentTime
                    }
                }
                
                // Slider sections
                VStack(alignment: .leading, spacing: 24) {
                    // Speed
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("PrimaryText"))
                            
                                Button("Reset") {
                                    audioPlayer.setSpeedRate(1.0)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .tint(Color("PrimaryBg"))
                                .opacity(audioPlayer.speedRate == 1.0 ? 0 : 1)
                            
                            Spacer()
                            
                            Text(String(format: "%.2fx", audioPlayer.speedRate))
                                .font(.subheadline)
                                .foregroundColor(Color("PrimaryBg"))
                        }
                        
                        HStack {
                            Slider(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.speedRate)
                                    },
                                    set: { newVal in
                                        // Slider sends continuous values while dragging, so we snap to the nearest 0.05 to enforce stepping.
                                        let snapped = (newVal / 0.05).rounded() * 0.05
                                        audioPlayer.setSpeedRate(Float(snapped))
                                    }
                                ),
                                in: 0.25...2.0,
                                step: 0.05
                            )
                            .accentColor(Color("PrimaryBg"))
                            // `flex: 1` (???)
                            .frame(maxWidth: .infinity)
                            
                            Stepper(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.speedRate)
                                    },
                                    set: { newVal in
                                        audioPlayer.setSpeedRate(Float(newVal))
                                    }
                                ),
                                in: 0.25...2.0,
                                step: 0.01,
                            ) {}
                            .fixedSize()
                        }
                    }

                    
                    // Pitch (cents)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pitch")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("PrimaryText"))
                            
                                Button("Reset") {
                                    audioPlayer.setPitchByCents(0.0)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .tint(Color("PrimaryBg"))
                                .opacity(audioPlayer.pitchCents.isZero ? 0 : 1)
                            
                            Spacer()
                            
                            Text("\(Int(audioPlayer.pitchCents)) cents")
                                .font(.subheadline)
                                .foregroundColor(Color("PrimaryBg"))
                        }
                        
                        HStack {
                            Slider(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.pitchCents)
                                    },
                                    set: { newVal in
                                        // Slider sends continuous values while dragging, so we snap to the nearest 50 to enforce stepping.
                                        let snapped = (newVal / 50.0).rounded() * 50.0
                                        audioPlayer.setPitchByCents(Float(snapped))
                                    }
                                ),
                                in: -800.0...800.0,
                                step: 50
                            )
                            .accentColor(Color("PrimaryBg"))
                            .frame(maxWidth: .infinity)
                            
                            Stepper(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.pitchCents)
                                    },
                                    set: { newVal in
                                        audioPlayer.setPitchByCents(Float(newVal))
                                    }
                                ),
                                in: -800.0...800.0,
                                step: 10,
                            ) {}
                            .fixedSize()
                        }
                    }

                    
                    // Reverb
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Reverb")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("PrimaryText"))
                            
                                Button("Reset") {
                                    audioPlayer.setReverbMix(0.0)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .tint(Color("PrimaryBg"))
                                .opacity(audioPlayer.reverbMix > 0 ? 1 : 0)
                            
                            Spacer()
                            
                            Text("\(Int(audioPlayer.reverbMix))%")
                                .font(.subheadline)
                                .foregroundColor(Color("PrimaryBg"))
                        }
                        
                        HStack {
                            Slider(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.reverbMix)
                                    },
                                    set: { newVal in
                                        let snapped = (newVal / 5.0).rounded() * 5.0
                                        audioPlayer.setReverbMix(Float(snapped))
                                    }
                                ),
                                in: 0.0...100.0,
                                step: 5
                            )
                            .accentColor(Color("PrimaryBg"))
                            .frame(maxWidth: .infinity)
                            
                            Stepper(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.reverbMix)
                                    },
                                    set: { newVal in
                                        audioPlayer.setReverbMix(Float(newVal))
                                    }
                                ),
                                in: 0.0...100.0,
                                step: 1,
                            ) {}
                            .fixedSize()
                        }
                    }
                }

                lyricsSection
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveToLibrary()
                } label: {
                    Label(
                        "Download",
                        systemImage: !isDownloaded ? "arrow.down.circle" :
                                     isModified ? "arrow.down.circle.dotted" :
                                     "checkmark.circle"
                    )
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    draftTitle = libraryItem.title
                    draftArtists = libraryItem.artists
                    isEditSheetPresented = true
                } label: {
                    Label("Edit Metadata", systemImage: "pencil")
                }
            }
        }
        .onChange(of: audioPlayer.speedRate) { _, _ in
            audioPlayer.updateMetadataTitle(decoratedTitle())
        }
        .onChange(of: audioPlayer.reverbMix) { _, _ in
            audioPlayer.updateMetadataTitle(decoratedTitle())
        }
        .task(id: libraryItem.original_url) {
            lyricsState = .idle
            fetchLyricsIfNeeded()
        }
        .sheet(isPresented: $isEditSheetPresented) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                        Text("Edit Metadata")
                            .font(.headline)
                            .padding(.top, 24)
                    
                        VStack(spacing: 24) {
                            LabeledTextField(
                                label: "Title",
                                placeholder: "Title",
                                text: $draftTitle,
                                isSecure: false,
                                textContentType: nil,
                                keyboardType: .default,
                                autocapitalization: .words,
                                disableAutocorrection: true
                            )
                            
                            VStack(spacing: 12) {
                                ForEach(draftArtists.indices, id: \.self) { index in
                                    HStack(alignment: .bottom) {
                                        LabeledTextField(
                                            label: "Artist \(index + 1)",
                                            placeholder: "Artist name",
                                            text: Binding(
                                                get: { draftArtists[index] },
                                                set: { draftArtists[index] = $0 }
                                            ),
                                            isSecure: false,
                                            textContentType: nil,
                                            keyboardType: .default,
                                            autocapitalization: .words,
                                            disableAutocorrection: true,
                                            horizontalPadding: 0
                                        )

                                        Button {
                                            draftArtists.remove(at: index)
                                            if draftArtists.isEmpty {
                                                draftArtists = [""]
                                            }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title3)
                                                .tint(Color("PrimaryBg"))
                                        }
                                        .accessibilityLabel("Remove artist")
                                        .padding(.horizontal, 6)
                                        .padding(.bottom, 12)
                                    }
                                    .padding(.horizontal)
                                }

                                Button {
                                    draftArtists.append("")
                                    DispatchQueue.main.async {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            proxy.scrollTo("editSheetBottom", anchor: .bottom)
                                        }
                                    }
                                } label: {
                                    Label("Add Artist", systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.bordered)
                                .tint(Color("PrimaryBg"))
                                .padding(.top, 12)
                            }
                        }
                        
                        Color.clear
                            .frame(height: 1)
                            .id("editSheetBottom")
                    }
                    .padding(.bottom, 24)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
                        }
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryActionButton(
                    title: "Save",
                    isLoading: false,
                    isDisabled: false,
                    action: {
                        let trimmedArtists = draftArtists
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }

                        // Commit edits to meta on Save
                        libraryItem.title = draftTitle
                        libraryItem.artists = trimmedArtists

                        // Update now playing metadata
                        audioPlayer.updateMetadataTitle(decoratedTitle())
                        audioPlayer.updateMetadataArtist(formatArtists(libraryItem.artists))
                        isEditSheetPresented = false
                    }
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: SheetButtonHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .onPreferenceChange(SheetHeightKey.self) { newValue in
                if newValue > 0 {
                    editSheetContentHeight = newValue
                    editSheetHeight = editSheetDetentHeight
                }
            }
            .onPreferenceChange(SheetButtonHeightKey.self) { newValue in
                if newValue > 0 {
                    editSheetButtonHeight = newValue
                    editSheetHeight = editSheetDetentHeight
                }
            }
			.frame(maxWidth: .infinity, alignment: .top)
            .presentationDetents([.height(max(editSheetHeight, 280)), .large])
            .presentationBackground(BackgroundColor)
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
	NavigationStack {
		ZStack {
			BackgroundColor
				.ignoresSafeArea()
			
			__PlayerScreen(
                libraryItem: LibraryItem(
                    original_url: "https://www.youtube.com/watch?v=Sxu8wHE97Rk",
                    title: "Ude Dil Befikre (From \"Befikre\")",
                    artists: ["Vishal and Sheykhar", "Benny Dayal"],
                    thumbnail_url: "https://lh3.googleusercontent.com/viaCZKRr1hCygO8JQS6lLmhBqUVFXctO_9sOE7hwI-rS_JlYcCdqel9sAaGdQoFEFUR2R6ldsrr_c2L5=w544-h544-l90-rj",
                    thumbnail_width: 544,
                    thumbnail_height: 544,
                    thumbnail_is_square: true
                ),
				audioPlayer: AudioPlayerWithReverb(),
                filePath: Binding(
                    get: { "" },
                    set: { _ in }
                )
			)
		}
	}
}
