//
//  VideoPlayerControlsView.swift
//  DemoApp
//
//  Created by Niko Inas on 25.02.24.
//

import SwiftUI
import YBVRAppleSDK

/**
 The transport bar: jump back, play, jump forward, the seek bar between its two times, and the
 volume, subtitle and audio pickers - one row on the player's glass.
 
 Built from the same pieces as the visionOS transport controls - `PlayerControlButton`,
 `YBVRSlider`, `PlayerControlsPopoverContent` - so the two platforms look and behave alike.
 */
struct VideoPlayerControlsView<Model: PlayerControlsModel>: View {
    let vm: Model
    
    @State private var seekingValue = 0.0
    @State private var openPopover: PlayerControlsPopover?
    
    /// The transport adopts the saved volume when it appears; the volume picker keeps it.
    @AppStorage("volume") private var volume: Double = 0.5
    
    private static var pinReason: String { "controlsPopover" }
    
    var body: some View {
        HStack(spacing: 16) {
            transportButtons
            seekbar
            pickers
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .playerGlass(in: Capsule())
        .onAppear {
            vm.volume = volume
        }
        // While a picker is open the controls stay up, so they cannot time out from under it.
        .onChange(of: openPopover != nil) { _, isOpen in
            vm.overlay.setPinned(isOpen, reason: Self.pinReason)
        }
        .onDisappear {
            vm.overlay.setPinned(false, reason: Self.pinReason)
        }
    }
    
    // MARK: - Transport
    
    @ViewBuilder
    private var transportButtons: some View {
        HStack(spacing: 12) {
            PlayerControlButton(icon: "10.arrow.trianglehead.counterclockwise",
                                isDisabled: !vm.canSeek,
                                onInteract: vm.startOverlayTimer) {
                vm.jump(by: -10)
            }
            
            PlayerControlButton(icon: vm.isPlaying ? "pause.fill" : "play.fill",
                                isDisabled: vm.isLive && !vm.canSeek,
                                onInteract: vm.startOverlayTimer) {
                vm.togglePlayPause()
            }
            
            PlayerControlButton(icon: "10.arrow.trianglehead.clockwise",
                                isDisabled: !vm.canSeek || (vm.isLive && vm.isAtLiveEdge),
                                onInteract: vm.startOverlayTimer) {
                vm.jump(by: 10)
            }
        }
    }
    
    // MARK: - Seek bar
    
    @ViewBuilder
    private var seekbar: some View {
        HStack(spacing: 16) {
            if vm.isLive {
                // A live edge has nothing to scrub within, so the bar is decorative.
                YBVRSlider(value: .constant(1),
                           maxValue: .constant(1),
                           seekingValue: $seekingValue,
                           trackHeight: 8,
                           thumbSize: 0,
                           minimumTrackTintColor: .red)
                .allowsHitTesting(false)
                
                PlayerLiveBadge(vm: vm)
            } else {
                PlayerTimeLabel(seconds: vm.isScrubbing ? seekingValue : vm.position)
                
                YBVRSlider(value: .constant(vm.position),
                           maxValue: .constant(vm.duration),
                           seekingValue: $seekingValue,
                           trackHeight: 8,
                           thumbSize: 6,
                           minimumTrackTintColor: UIColor(.white.opacity(0.6)),
                           maximumTrackTintColor: UIColor(.black.opacity(0.5)),
                           adMarkers: vm.adMarkers,
                           onScrubBegan: { vm.beginScrub() },
                           onScrubEnded: {
                    vm.commitScrub(to: seekingValue)
                    vm.startOverlayTimer()
                })
                .allowsHitTesting(vm.canSeek)
                
                PlayerTimeLabel(seconds: vm.duration)
            }
        }
    }
    
    // MARK: - Pickers
    
    @ViewBuilder
    private var pickers: some View {
        HStack(spacing: 12) {
            pickerButton(.volume, icon: "speaker.wave.2.fill", isDisabled: false)
            
            pickerButton(.captions,
                         icon: "captions.bubble",
                         isDisabled: vm.selectableSubtitlesLanguages.isEmpty)
            
            pickerButton(.languages,
                         icon: "globe",
                         isDisabled: vm.selectableAudioLanguages.count <= 1)
        }
    }
    
    @ViewBuilder
    private func pickerButton(_ popover: PlayerControlsPopover,
                              icon: String,
                              isDisabled: Bool) -> some View {
        PlayerControlButton(
            icon: icon,
            isSelected: openPopover == popover,
            isDisabled: isDisabled,
            onInteract: vm.startOverlayTimer
        ) {
            openPopover = openPopover == popover ? nil : popover
        }
        .popover(isPresented: isPresented(popover), arrowEdge: .bottom) {
            PlayerControlsPopoverContent(vm: vm, popover: popover)
                .preferredColorScheme(.dark)
        }
    }
    
    private func isPresented(_ popover: PlayerControlsPopover) -> Binding<Bool> {
        Binding(get: { openPopover == popover },
                set: { isPresented in
            if isPresented {
                openPopover = popover
            } else if openPopover == popover {
                openPopover = nil
            }
        })
    }
}

#Preview("VOD", traits: .landscapeLeft) {
    VideoPlayerControlsView(vm: StreamViewModel(video: .init(
        id: 1, mediaId: nil, name: "Name", description: "Desc", duration: "10:00",
        urlString: "", isLive: false, signalingVersion: nil, categories: [], poster: "",
        activationEpoch: nil, expirationEpoch: nil, forcedGeometryId: nil, forcedStereo: nil,
        interactableUrl: nil, visibility: nil, isTimeShiftingAllowed: nil
    )))
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(Color(white: 0.27))
}

#Preview("LIVE", traits: .landscapeLeft) {
    VideoPlayerControlsView(vm: StreamViewModel(video: .example))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color(white: 0.27))
}
