//
//  PlayerTransportControls.swift
//  Shared
//

import SwiftUI
import YBVRAppleSDK

/**
 The playback controls, for anything that conforms to `PlayerControlsModel`.
 
 The title, the seek bar, and a row of transport buttons and pickers, on the window's glass.
 The pickers open as popovers from their buttons, and close on a press outside them or on
 their button again.
 */
struct PlayerTransportControls<Model: PlayerControlsModel>: View {
    
    let vm: Model
    
    @State private var openPopover: PlayerControlsPopover?
    @State private var seekingValue = 0.0
    
    @AppStorage("volume") private var volume: Double = 0.5
    
    var body: some View {
        VStack(spacing: 24) {
            header
            seekbar
            controls
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 40)
        .frame(width: 658)
        .glassBackgroundEffect()
        .onAppear {
            vm.volume = volume
        }
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private var header: some View {
        let title = vm.headerTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = vm.headerSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle: String = title + (!title.isEmpty && !subtitle.isEmpty ? " - " : "") + subtitle
        
        Text(displayTitle)
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(height: 32)
    }
    
    // MARK: - Controls
    
    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 0) {
            HStack(spacing: 20) {
                PlayerControlButton(icon: "arrow.backward") {
                    vm.requestDismiss()
                }
                pickerButton(.volume, icon: "speaker.wave.2.fill", isDisabled: false,
                             anchor: .bottom, arrowEdge: .top)
            }
            
            Spacer(minLength: 0)
            
            HStack(spacing: 24) {
                PlayerControlButton(icon: "10.arrow.trianglehead.counterclockwise",
                                    isDisabled: !vm.canJumpBack) {
                    vm.jump(by: -10)
                }
                
                PlayerControlButton(icon: vm.isPlaying ? "pause.fill" : "play.fill",
                                    isDisabled: !vm.canSeek) {
                    vm.togglePlayPause()
                }
                
                PlayerControlButton(icon: "10.arrow.trianglehead.clockwise",
                                    isDisabled: !vm.canJumpForward) {
                    vm.jump(by: 10)
                }
            }
            
            Spacer(minLength: 0)
            
            HStack(spacing: 20) {
                pickerButton(.captions, icon: "captions.bubble",
                             isDisabled: vm.selectableSubtitlesLanguages.isEmpty,
                             anchor: .trailing, arrowEdge: .leading)
                
                pickerButton(.languages, icon: "globe",
                             isDisabled: vm.selectableAudioLanguages.count <= 1,
                             anchor: .trailing, arrowEdge: .leading)
            }
        }
    }
    
    // MARK: - Pickers
    
    private func pickerButton(_ picker: PlayerControlsPopover,
                              icon: String,
                              isDisabled: Bool,
                              anchor: UnitPoint,
                              arrowEdge: Edge) -> some View {
        PlayerControlButton(icon: icon,
                            isSelected: openPopover == picker,
                            isDisabled: isDisabled) {
            openPopover = openPopover == picker ? nil : picker
        }
        .popover(isPresented: isPresented(picker),
                 attachmentAnchor: .point(anchor),
                 arrowEdge: arrowEdge) {
            PlayerControlsPopoverContent(vm: vm, popover: picker)
        }
    }
    
    private func isPresented(_ picker: PlayerControlsPopover) -> Binding<Bool> {
        Binding(get: { openPopover == picker },
                set: { isPresented in
            if isPresented {
                openPopover = picker
            } else if openPopover == picker {
                openPopover = nil
            }
        })
    }
}
