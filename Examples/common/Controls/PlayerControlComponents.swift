//
//  PlayerControlComponents.swift
//  DemoApp
//
//  Shared by the iOS and visionOS demo apps.
//

import SwiftUI
import YBVRAppleSDK

// MARK: - Glass

extension View {
    /**
     The translucent panel the player controls sit on.
     
     visionOS's own glass there; Liquid Glass on iOS 26 and later, and a dark material before it.
     Dark in both cases: glass takes its brightness from the colour scheme and from what is
     behind it, and over video in the light scheme it reads as a milky white panel that washes
     the white controls out. `tint` darkens it further, as the design has it.
     */
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

/// The LIVE badge that stands in for the timestamps on live content. Dimmed away from the live
/// edge, and a way back to it where the stream can be seeked.
struct PlayerLiveBadge<Model: PlayerControlsModel>: View {
    let vm: Model
    
    var body: some View {
        Button {
            vm.goToLive()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 14, height: 14)
                Text("LIVE")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .opacity(vm.isAtLiveEdge ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.capsule)
        .disabled(!vm.canSeek)
    }
}

// MARK: - Button

/// The round button every player control is built from, on both platforms - so whatever a
/// pipeline adds matches what is already there.
struct PlayerControlButton: View {
    
    let icon: String
    var isSelected: Bool = false
    var isDisabled: Bool = false
    
    /// Called before `action`, so any interaction also keeps the controls on screen.
    var onInteract: () -> Void = { }
    
    let action: () -> Void
    
    var body: some View {
        Button {
            onInteract()
            action()
        } label: {
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

/// What each picker shows. Its own view so that a host presenting the pickers itself - through
/// a `PresentationComponent`, say - shows exactly what the popovers here do.
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
    
    @AppStorage("volume") private var volume: Double = 1
    
    var body: some View {
        switch popover {
        case .volume: volumeControl
        case .captions: captionOptions
        case .languages: languageOptions
        }
    }
    
    @ViewBuilder
    private var volumeControl: some View {
        YBVRSlider(value: $volume,
                   maxValue: .constant(1),
                   seekingValue: $volume,
                   trackHeight: 8,
                   thumbSize: 6,
                   minimumTrackTintColor: UIColor(.white.opacity(0.6)),
                   maximumTrackTintColor: UIColor(.black.opacity(0.5)),)
        .onChange(of: volume) {
            vm.volume = volume
            vm.startOverlayTimer()
        }
        .padding(.horizontal, 16)
        .frame(width: 245, height: 44)
        .presentationCompactAdaptation(.popover)
    }
    
    @ViewBuilder
    private var captionOptions: some View {
        languageList(title: "Subtitles",
                     languages: vm.availableSubtitlesLanguages,
                     selectable: vm.selectableSubtitlesLanguages,
                     current: vm.currentSubtitlesLanguage,
                     offerOff: true) { language in
            await vm.setSubtitlesLanguage(language)
        }
    }
    
    @ViewBuilder
    private var languageOptions: some View {
        languageList(title: "Languages",
                     languages: vm.availableAudioLanguages,
                     selectable: vm.selectableAudioLanguages,
                     current: vm.currentAudioLanguage,
                     offerOff: false) { language in
            await vm.setAudioLanguage(language)
        }
    }
    
    /// One list for both pickers: the audio one has no "off", since something has to play.
    @ViewBuilder
    private func languageList(title: String,
                              languages: [String],
                              selectable: [String],
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
                        optionRow(title: language,
                                  isSelected: current == language,
                                  isDisabled: !selectable.contains(language)) {
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
        .presentationCompactAdaptation(.popover)
    }
    
    @ViewBuilder
    private func optionRow(title: String,
                           isSelected: Bool,
                           isDisabled: Bool = false,
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
        .background(isSelected ? .white : .clear, in: RoundedRectangle(cornerRadius: 16))
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .buttonStyle(.borderless)
        .disabled(isDisabled)
        .animation(.easeInOut, value: isSelected)
    }
}
