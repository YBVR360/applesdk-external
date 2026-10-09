//
//  VideoPlayerControlsView.swift
//  Shared
//
//  Created by Niko Inas on 25.02.24.
//

import SwiftUI
import YBVRAppleSDK

/**
 The transport bar: jump back, play, jump forward, the seek bar between its two times, and the
 volume, subtitle and audio pickers - one row on the player's glass.
 */
struct VideoPlayerControlsView<Model: PlayerControlsModel>: View {
    let vm: Model
    
    @State private var seekingValue = 0.0
    @State private var openPopover: PlayerControlsPopover?
    /// The picker whose popover is still on screen - up until its dismissal has finished.
    @State private var presentedPopover: PlayerControlsPopover?
    /// A picker asked for while another is still closing, opened once that one has gone.
    @State private var pendingPopover: PlayerControlsPopover?
    
    /// The transport adopts the saved volume when it appears; the volume picker keeps it.
    @AppStorage("volume") private var volume: Double = 0.5
    
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
    }
    
    // MARK: - Transport
    
    @ViewBuilder
    private var transportButtons: some View {
        HStack(spacing: 12) {
            PlayerControlButton(icon: "gobackward.10", isDisabled: !vm.canJumpBack) {
                vm.jump(by: -10)
            }
            
            PlayerControlButton(icon: vm.isPlaying ? "pause.fill" : "play.fill",
                                isDisabled: vm.isLive && !vm.canSeek) {
                vm.togglePlayPause()
            }
            
            PlayerControlButton(icon: "goforward.10", isDisabled: !vm.canJumpForward) {
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
                           onScrubBegan: { vm.beginScrub() },
                           onScrubEnded: { vm.commitScrub(to: seekingValue) })
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
            isSelected: openPopover == popover || pendingPopover == popover,
            isDisabled: isDisabled
        ) {
            toggle(popover)
        }
        .popover(isPresented: isPresented(popover), arrowEdge: .bottom) {
            PlayerControlsPopoverContent(vm: vm, popover: popover)
                .preferredColorScheme(.dark)
                .onAppear { presentedPopover = popover }
                .onDisappear { popoverDidDismiss(popover) }
        }
    }
    
    private func toggle(_ popover: PlayerControlsPopover) {
        if openPopover == popover || pendingPopover == popover {
            openPopover = nil
            pendingPopover = nil
        } else if presentedPopover != nil {
            // Another picker is open or still closing: close it, and open this one after.
            openPopover = nil
            pendingPopover = popover
        } else {
            openPopover = popover
        }
    }
    
    private func popoverDidDismiss(_ popover: PlayerControlsPopover) {
        guard presentedPopover == popover else { return }
        presentedPopover = nil
        if let next = pendingPopover {
            pendingPopover = nil
            openPopover = next
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
