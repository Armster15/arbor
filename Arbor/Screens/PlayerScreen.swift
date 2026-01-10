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

private func decoratedTitle(for libraryItem: LibraryItem, audioPlayer: AudioPlayerWithReverb) -> String {
    var tags: [String] = []
    if audioPlayer.speedRate > 1.0 {
        tags.append("sped up")
    } else if audioPlayer.speedRate < 1.0 {
        tags.append("slowed")
    }
    if audioPlayer.reverbMix > 0.0 {
        tags.append("reverb")
    }
    guard !tags.isEmpty else { return libraryItem.title }
    return "\(libraryItem.title) (\(tags.joined(separator: " + ")))"
}

struct __PlayerScreen: View {
    @Bindable var libraryItem: LibraryItem
    let audioPlayer: AudioPlayerWithReverb
    @Binding var filePath: String
    
    @State private var isEditSheetPresented: Bool = false
    @State private var lyricsState: LyricsState = .idle
    @State private var currentLyricsTaskId: UUID?
    
    // Track last saved settings locally (not persisted to iCloud)
    @State private var savedSpeedRate: Float?
    @State private var savedPitchCents: Float?
    @State private var savedReverbMix: Float?

    @Environment(\.modelContext) var modelContext

    private enum LyricsState: Equatable {
        case idle
        case loading
        case loaded(LyricsPayload)
        case empty
        case failed
    }

    private var isDownloaded: Bool {
        getLocalAudioFilePath(originalUrl: libraryItem.original_url) != nil
    }
    
    init(libraryItem: LibraryItem, audioPlayer: AudioPlayerWithReverb, filePath: Binding<String>) {
        self.libraryItem = libraryItem
        self.audioPlayer = audioPlayer
        self._filePath = filePath
    }

    private func fetchLyricsIfNeeded() {
        let taskId = UUID()
        currentLyricsTaskId = taskId
        lyricsState = .loading

        LyricsCache.shared.fetchLyrics(
            originalUrl: libraryItem.original_url,
            title: libraryItem.title,
            artists: libraryItem.artists
        ) { result in
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

    private var lyricsSection: some View {
        Group {
            if case .loaded(let payload) = lyricsState, !payload.lines.isEmpty {
                LyricsView(
                    payload: payload,
                    audioPlayer: audioPlayer,
                    originalUrl: libraryItem.original_url
                )
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
                    
                    PlayerControlsSection(audioPlayer: audioPlayer)
                }
                
                PlayerAdjustmentsSection(audioPlayer: audioPlayer)
                lyricsSection
                PlayerMetadataSyncView(libraryItem: libraryItem, audioPlayer: audioPlayer)
            }
            .padding()
        }
        .toolbar {
            PlayerToolbar(
                audioPlayer: audioPlayer,
                isDownloaded: isDownloaded,
                libraryItemSpeedRate: libraryItem.speedRate,
                libraryItemPitchCents: libraryItem.pitchCents,
                libraryItemReverbMix: libraryItem.reverbMix,
                savedSpeedRate: savedSpeedRate,
                savedPitchCents: savedPitchCents,
                savedReverbMix: savedReverbMix,
                onSave: { saveToLibrary() },
                onEdit: { isEditSheetPresented = true }
            )
        }
        .task(id: libraryItem.original_url) {
            lyricsState = .idle
            fetchLyricsIfNeeded()
        }
        .sheet(isPresented: $isEditSheetPresented) {
            PlayerMetadataSheet(
                libraryItem: libraryItem,
                audioPlayer: audioPlayer,
                onLyricsInvalidated: { fetchLyricsIfNeeded() },
                isPresented: $isEditSheetPresented
            )
        }
    }
}

private struct PlayerControlsSection: View {
    @ObservedObject var audioPlayer: AudioPlayerWithReverb

    @State private var isScrubbing: Bool = false
    @State private var scrubberTime: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                HStack(spacing: 16) {
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
                            .clear
                        )
                        .accessibilityLabel(
                            audioPlayer.isLooping ? "Disable Loop" : "Enable Loop"
                        )
                    }
                }
            }

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
    }
}

private struct PlayerAdjustmentsSection: View {
    @ObservedObject var audioPlayer: AudioPlayerWithReverb

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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
                                let snapped = (newVal / 0.05).rounded() * 0.05
                                audioPlayer.setSpeedRate(Float(snapped))
                            }
                        ),
                        in: 0.25...2.0,
                        step: 0.05
                    )
                    .accentColor(Color("PrimaryBg"))
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
    }
}

private struct PlayerToolbar: ToolbarContent {
    @ObservedObject var audioPlayer: AudioPlayerWithReverb
    let isDownloaded: Bool
    let libraryItemSpeedRate: Float
    let libraryItemPitchCents: Float
    let libraryItemReverbMix: Float
    let savedSpeedRate: Float?
    let savedPitchCents: Float?
    let savedReverbMix: Float?
    let onSave: () -> Void
    let onEdit: () -> Void

    private var isModified: Bool {
        let refSpeed = savedSpeedRate ?? libraryItemSpeedRate
        let refPitch = savedPitchCents ?? libraryItemPitchCents
        let refReverb = savedReverbMix ?? libraryItemReverbMix

        return audioPlayer.speedRate != refSpeed ||
            audioPlayer.pitchCents != refPitch ||
            audioPlayer.reverbMix != refReverb
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                onSave()
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
                onEdit()
            } label: {
                Label("Edit Metadata", systemImage: "pencil")
            }
        }
    }
}

private struct PlayerMetadataSyncView: View {
    let libraryItem: LibraryItem
    @ObservedObject var audioPlayer: AudioPlayerWithReverb

    var body: some View {
        EmptyView()
            .onChange(of: audioPlayer.speedRate) { _, _ in
                audioPlayer.updateMetadataTitle(decoratedTitle(for: libraryItem, audioPlayer: audioPlayer))
            }
            .onChange(of: audioPlayer.reverbMix) { _, _ in
                audioPlayer.updateMetadataTitle(decoratedTitle(for: libraryItem, audioPlayer: audioPlayer))
            }
    }
}

private struct PlayerMetadataSheet: View {
    @Bindable var libraryItem: LibraryItem
    @ObservedObject var audioPlayer: AudioPlayerWithReverb
    let onLyricsInvalidated: () -> Void
    @Binding var isPresented: Bool

    @State private var draftTitle: String = ""
    @State private var draftArtists: [String] = []
    @State private var editSheetHeight: CGFloat = 0
    @State private var editSheetContentHeight: CGFloat = 0
    @State private var editSheetButtonHeight: CGFloat = 0
    @State private var hasInitialized: Bool = false

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

    private func initializeDraftsIfNeeded() {
        guard !hasInitialized else { return }
        draftTitle = libraryItem.title
        draftArtists = libraryItem.artists
        hasInitialized = true
    }

    var body: some View {
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
                    let previousTitle = libraryItem.title
                    let previousArtists = libraryItem.artists
                    let trimmedArtists = draftArtists
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    let nextTitle = draftTitle
                    let nextArtists = trimmedArtists

                    libraryItem.title = nextTitle
                    libraryItem.artists = trimmedArtists

                    audioPlayer.updateMetadataTitle(decoratedTitle(for: libraryItem, audioPlayer: audioPlayer))
                    audioPlayer.updateMetadataArtist(formatArtists(libraryItem.artists))

                    if previousTitle != nextTitle || previousArtists != nextArtists {
                        LyricsCache.shared.clearLyrics(originalURL: libraryItem.original_url)
                        onLyricsInvalidated()
                    }

                    isPresented = false
                }
            )
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SheetButtonHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .onAppear {
            initializeDraftsIfNeeded()
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


private enum LyricsDisplayMode: String, CaseIterable {
    case original = "Original"
    case romanized = "Romanized"
    case translated = "Translated"
}

private struct LyricsView: View {
    let payload: LyricsPayload
    @ObservedObject var audioPlayer: AudioPlayerWithReverb
    let originalUrl: String

    @State private var lastActiveLyricIndex: Int?
    @State private var romanizedLyricLines: [String]?
    @State private var translatedLyricLines: [String]?
    @State private var isTranslatingLyrics: Bool = false
    @State private var lyricsDisplayMode: LyricsDisplayMode = .original
    @State private var currentTranslateTaskId: UUID?
    @State private var lastPlaybackTimeMs: Int?
    @State private var isAutoScrollEnabled: Bool = true

    private func translateLyrics() {
        guard !isTranslatingLyrics else { return }
        isTranslatingLyrics = true
        let taskId = UUID()
        currentTranslateTaskId = taskId
        LyricsCache.shared.translateLyrics(originalUrl: originalUrl, payload: payload) { result in
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

    private func resetTranslationState() {
        romanizedLyricLines = nil
        translatedLyricLines = nil
        lyricsDisplayMode = .original
        isTranslatingLyrics = false
        currentTranslateTaskId = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LyricsHeaderView(
                isTranslatingLyrics: isTranslatingLyrics,
                lyricsDisplayMode: lyricsDisplayMode,
                lyricsSource: payload.source,
                showsSync: payload.timed && !isAutoScrollEnabled,
                onSync: {
                    isAutoScrollEnabled = true
                }
            ) { mode in
                let needsTranslation = (mode == .romanized || mode == .translated)
                    && (romanizedLyricLines == nil || translatedLyricLines == nil)
                lyricsDisplayMode = mode
                if needsTranslation {
                    DispatchQueue.main.async {
                        translateLyrics()
                    }
                }
            }

            let currentMs = Int(audioPlayer.currentTime * 1000)
            let shouldShowActive = payload.timed
                && (currentMs > 0 || audioPlayer.isPlaying || lastPlaybackTimeMs != nil)
            let activeIndex = shouldShowActive
                ? LyricsCache.activeLyricIndex(for: payload, currentTimeMs: currentMs)
                : nil
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
                .frame(maxHeight: 260)
                .scrollIndicators(.hidden)
                .onChange(of: activeIndex) { _, newValue in
                    guard payload.timed, isAutoScrollEnabled else { return }
                    guard let newValue, newValue != lastActiveLyricIndex else { return }
                    scrollToActiveLyric(proxy, activeIndex: newValue, shouldAnimate: true)
                }
                .onChange(of: audioPlayer.currentTime) { _, newValue in
                    guard payload.timed, isAutoScrollEnabled else { return }
                    let newMs = Int(newValue * 1000)
                    if let lastMs = lastPlaybackTimeMs {
                        let jumped = abs(newMs - lastMs) > 1500
                        if jumped {
                            let jumpedIndex = LyricsCache.activeLyricIndex(
                                for: payload,
                                currentTimeMs: newMs
                            )
                            if let jumpedIndex {
                                lastActiveLyricIndex = jumpedIndex
                            }
                            scrollToActiveLyric(proxy, activeIndex: jumpedIndex, shouldAnimate: false)
                        }
                        if newMs < lastMs && newMs < 500 {
                            lastActiveLyricIndex = 0
                            scrollToActiveLyric(proxy, activeIndex: 0, shouldAnimate: false)
                        }
                    }
                    lastPlaybackTimeMs = newMs
                }
                .onChange(of: lyricsDisplayMode) { _, newValue in
                    guard payload.timed, isAutoScrollEnabled else { return }
                    DispatchQueue.main.async {
                        scrollToActiveLyric(proxy, activeIndex: activeIndex, shouldAnimate: false)
                    }
                }
                .onChange(of: romanizedLyricLines) { _, _ in
                    guard payload.timed, isAutoScrollEnabled else { return }
                    DispatchQueue.main.async {
                        scrollToActiveLyric(proxy, activeIndex: activeIndex, shouldAnimate: false)
                    }
                }
                .onChange(of: translatedLyricLines) { _, _ in
                    guard payload.timed, isAutoScrollEnabled else { return }
                    DispatchQueue.main.async {
                        scrollToActiveLyric(proxy, activeIndex: activeIndex, shouldAnimate: false)
                    }
                }
                .onChange(of: payload) { _, _ in
                    resetTranslationState()
                    isAutoScrollEnabled = true
                }
                // scroll to the active lyric on appear (e.g. when player is reopened)
                .onAppear {
                    guard payload.timed, isAutoScrollEnabled else { return }
                    scrollToActiveLyric(proxy, activeIndex: activeIndex, shouldAnimate: false)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 2).onChanged { _ in
                        guard payload.timed else { return }
                        isAutoScrollEnabled = false
                    }
                )
                .onChange(of: isAutoScrollEnabled) { _, newValue in
                    guard payload.timed, newValue else { return }
                    scrollToActiveLyric(proxy, activeIndex: activeIndex, shouldAnimate: true)
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

private struct LyricsHeaderView: View, Equatable {
    let isTranslatingLyrics: Bool
    let lyricsDisplayMode: LyricsDisplayMode
    let lyricsSource: LyricsSource?
    let showsSync: Bool
    let onSync: () -> Void
    let onSelect: (LyricsDisplayMode) -> Void

    @Environment(\.colorScheme) var colorScheme

    static func == (lhs: LyricsHeaderView, rhs: LyricsHeaderView) -> Bool {
        lhs.isTranslatingLyrics == rhs.isTranslatingLyrics
            && lhs.lyricsDisplayMode == rhs.lyricsDisplayMode
            && lhs.lyricsSource == rhs.lyricsSource
            && lhs.showsSync == rhs.showsSync
    }

    var body: some View {
        HStack {
            Text("Lyrics")
                .font(.headline)
                .foregroundColor(Color("PrimaryText"))

            Spacer()

            if isTranslatingLyrics {
                ProgressView()
                    .scaleEffect(0.7)
            }

            if showsSync {
                Button("Sync") {
                    onSync()
                }
                .font(.callout)
                .foregroundColor(Color("PrimaryText"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(colorScheme == .light ? Color("Elevated") : Color("SecondaryBg"))
                .clipShape(Capsule())
            }

            Menu {
                ForEach(LyricsDisplayMode.allCases, id: \.self) { mode in
                    Button {
                        onSelect(mode)
                    } label: {
                        if lyricsDisplayMode == mode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
                if let lyricsSource {
                    Divider()
                    Button {} label: {
                        Text("Source: \(lyricsSource.rawValue)")
                    }
                    .disabled(true)
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
