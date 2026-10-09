//
//  PlayerControlComponents.swift
//  Shared
//
//  Shared by the iOS and visionOS apps.
//

import SwiftUI
import YBVRAppleSDK

// MARK: - Glass

extension View {
    
    @ViewBuilder
    func playerGlass<S: InsettableShape>(in shape: S) -> some View {
#if os(visionOS)
        glassBackgroundEffect(in: shape)
#else
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(.black.opacity(0.35)), in: shape)
                .environment(\.colorScheme, .dark)
        } else {
            background(.ultraThinMaterial, in: shape)
                .environment(\.colorScheme, .dark)
                .overlay(shape.strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
#endif
    }
}

// MARK: - Time and live

/// A playback time, as the seek bar labels its two ends.
struct PlayerTimeLabel: View {
    let seconds: Double
    
    var body: some View {
        Text(TimeFormat.formatSecondsToHMS(seconds))
            .font(.system(.caption2, design: .monospaced, weight: .medium))
            .foregroundStyle(Color(red: 196 / 255, green: 196 / 255, blue: 196 / 255))
            .monospacedDigit()
    }
}

/// The LIVE badge that stands in for the timestamps on live content.
struct PlayerLiveBadge<Model: PlayerControlsModel>: View {
    let vm: Model
    
    private var isBehind: Bool { !vm.isAtLiveEdge && vm.canSeek }
    
    var body: some View {
        Button {
            vm.goToLive()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isBehind ? .gray : .red)
                    .frame(width: 14, height: 14)
                Text("LIVE")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.capsule)
        .allowsHitTesting(isBehind)
    }
}

// MARK: - Subtitles

/// The subtitle cue, drawn by the app directly above the playback controls.
struct PlayerSubtitles: View {
    let cue: String?
#if os(visionOS)
    private let fontSize: CGFloat = 20
#else
    private let fontSize: CGFloat = 14
#endif
    
    var body: some View {
        if let cue, !cue.isEmpty {
            Text(cue)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Button

/// The round button every player control is built from, on both platforms
struct PlayerControlButton: View {
    
    let icon: String
    var isSelected: Bool = false
    var isDisabled: Bool = false
    
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .padding(8)
                .background(isSelected ? .white : .clear, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .foregroundStyle(isSelected ? .black : .white)
        .disabled(isDisabled)
        .animation(.easeInOut, value: icon)
        .animation(.easeInOut, value: isSelected)
        .animation(.easeInOut, value: isDisabled)
    }
}

// MARK: - Pickers

/// The pickers the controls open.
enum PlayerControlsPopover: Hashable, CaseIterable {
    case volume
    case captions
    case languages
}

/// What each picker shows.
struct PlayerControlsPopoverContent<Model: PlayerControlsModel>: View {
    
    let vm: Model
    let popover: PlayerControlsPopover
    
    /// The options' own height, which the list is sized to until it reaches `maxListHeight`.
    @State private var listHeight: CGFloat = 0
    
    /// The tallest the options get before they scroll. A landscape phone has the least room.
#if os(visionOS)
    private static var maxListHeight: CGFloat { 440 }
#else
    private static var maxListHeight: CGFloat { 220 }
#endif
    
    @AppStorage("volume") private var volume: Double = 0.5
    
    var body: some View {
        Group {
            switch popover {
            case .volume: volumeControl
            case .captions: captionOptions
            case .languages: languageOptions
            }
        }
        .presentationCompactAdaptation(.popover)
    }
    
    @ViewBuilder
    private var volumeControl: some View {
        YBVRSlider(value: $volume,
                   maxValue: .constant(1),
                   seekingValue: $volume,
                   trackHeight: 8,
                   thumbSize: 6,
                   minimumTrackTintColor: UIColor(.white.opacity(0.6)),
                   maximumTrackTintColor: UIColor(.black.opacity(0.5)))
        .onChange(of: volume) {
            vm.volume = volume
        }
        .padding(.horizontal, 16)
        .frame(width: 245, height: 44)
    }
    
    @ViewBuilder
    private var captionOptions: some View {
        languageList(title: "Subtitles",
                     languages: vm.selectableSubtitlesLanguages,
                     current: vm.currentSubtitlesLanguage,
                     offerOff: true) { language in
            await vm.setSubtitlesLanguage(language)
        }
    }
    
    @ViewBuilder
    private var languageOptions: some View {
        languageList(title: "Languages",
                     languages: vm.selectableAudioLanguages,
                     current: vm.currentAudioLanguage,
                     offerOff: false) { language in
            await vm.setAudioLanguage(language)
        }
    }
    
    /// One list for both pickers: the audio one has no "off", since something has to play.
    @ViewBuilder
    private func languageList(title: String,
                              languages: [String],
                              current: String,
                              offerOff: Bool,
                              select: @escaping (String) async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 28)
                .padding(.horizontal, 34)
                .padding(.bottom, 10)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if offerOff {
                        optionRow(title: "Off", isSelected: current.isEmpty) {
                            Task { await select("") }
                        }
                    }
                    
                    ForEach(languages, id: \.self) { language in
                        optionRow(title: language, isSelected: current == language) {
                            Task { await select(language) }
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
            }
            .frame(height: min(listHeight, Self.maxListHeight))
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .padding(.top, 10)
            .padding([.horizontal, .bottom], 24)
        }
        .frame(minWidth: 280, alignment: .leading)
    }
    
    @ViewBuilder
    private func optionRow(title: String,
                           isSelected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text(title)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(isSelected ? .white : .clear,
                    in: RoundedRectangle(cornerRadius: 16))
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .buttonStyle(.borderless)
        .animation(.easeInOut, value: isSelected)
    }
}

// MARK: - Action bar

/**
 The bar above the playback controls that changes how the video is experienced - the camera
 map, the multiview - as opposed to the controls, which change what plays.
 */
struct ActionBar: View {
    
    struct Action: Identifiable {
        let title: String
        let icon: String
        var isActive: Bool = false
        let perform: () -> Void
        
        var id: String { title }
    }
    
    let actions: [Action]
    
    var body: some View {
        if !actions.isEmpty {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    pill(for: action)
                }
            }
            .padding(8)
            .playerGlass(in: Capsule())
        }
    }
    
    @ViewBuilder
    private func pill(for action: Action) -> some View {
        Button(action: action.perform) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                
                Text(action.title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .strokeBorder(action.isActive ? Color.white.opacity(0.4) : Color.black.opacity(0.4),
                                  lineWidth: 1)
                    .fill(action.isActive ? .white.opacity(0.2) : .clear)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.capsule)
        .animation(.easeInOut(duration: 0.15), value: action.isActive)
    }
}
