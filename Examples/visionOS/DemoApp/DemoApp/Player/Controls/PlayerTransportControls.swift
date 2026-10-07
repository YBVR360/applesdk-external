//
//  PlayerTransportControls.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

/**
 The transport controls, for anything that conforms to `PlayerControlsModel`.
 
 Both pipelines the demo exercises need the same row of controls - back, seek bar, play, jump,
 languages, volume - so it is written once here and handed whichever model is playing:
 `PlayerCoordinator` for the YBVR pipeline, `DirectPlayerViewModel` for plain HLS.
 
 `extras` is the slot for whatever only one of them has. The YBVR controls put the surface
 switch button there; the Direct Player passes nothing.
 
 The pickers are SwiftUI popovers, which need a window to present from. A host without one - a
 RealityView attachment in an immersive space - passes `popover` to own which picker is open,
 and presents `PlayerControlsPopoverContent` itself; the buttons then only set that binding.
 */
struct PlayerTransportControls<Model: PlayerControlsModel, Extras: View>: View {
    
    let vm: Model
    
    /// Which picker is open, when the host presents them. `nil` to present them here.
    let popover: Binding<PlayerControlsPopover?>?
    
    @ViewBuilder let extras: () -> Extras
    
    @State private var localPopover: PlayerControlsPopover?
    @State private var seekingValue = 0.0
    
    @AppStorage("volume") private var volume: Double = 0.5
    
    init(vm: Model,
         popover: Binding<PlayerControlsPopover?>? = nil,
         @ViewBuilder extras: @escaping () -> Extras) {
        self.vm = vm
        self.popover = popover
        self.extras = extras
    }
    
    private var openPopover: Binding<PlayerControlsPopover?> {
        popover ?? $localPopover
    }
    
    /// While any picker is open the controls stay up, so they cannot time out from under it.
    private var isAnyPopoverOpen: Bool {
        openPopover.wrappedValue != nil
    }
    
    private func isOpen(_ picker: PlayerControlsPopover) -> Bool {
        openPopover.wrappedValue == picker
    }
    
    private func toggle(_ picker: PlayerControlsPopover) {
        openPopover.wrappedValue = isOpen(picker) ? nil : picker
    }
    
    /// Drives a SwiftUI `.popover` for `picker` - but only when this view presents them; a host
    /// that presents them itself gets a binding that never opens.
    private func presentsHere(_ picker: PlayerControlsPopover) -> Binding<Bool> {
        guard popover == nil else { return .constant(false) }
        return Binding(get: { localPopover == picker },
                       set: { isPresented in
            if isPresented {
                localPopover = picker
            } else if localPopover == picker {
                localPopover = nil
            }
        })
    }
    
    /// Whether the controls are held still under an open host-presented picker. A window's own
    /// popovers already keep the controls under them from reacting; the host's need this.
    private var isBlockedByPopover: Bool {
        popover != nil && isAnyPopoverOpen
    }
    
    var body: some View {
        VStack(spacing: 24) {
            header
            seekbar
            controls
        }
        // While a picker is open, a tap on the controls only closes it, as it would a popover:
        // the buttons and sliders let it through to the panel's own tap below.
        .allowsHitTesting(!isBlockedByPopover)
        .padding(.vertical, 24)
        .padding(.horizontal, 40)
        .frame(width: 658)
        .glassBackgroundEffect()
        .onAppear {
            vm.volume = volume
        }
        .onChange(of: isAnyPopoverOpen) { _, isOpen in
            vm.overlay.setPinned(isOpen, reason: Self.pinReason)
        }
        .onDisappear {
            vm.overlay.setPinned(false, reason: Self.pinReason)
        }
        .onTapGesture {
            if isBlockedByPopover {
                openPopover.wrappedValue = nil
            }
            vm.startOverlayTimer()
        }
    }
    
    private static var pinReason: String { "controlsPopover" }
    
    // MARK: - Header
    
    @ViewBuilder
    private var header: some View {
        let title = vm.headerTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = vm.headerSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle: String = title + (!title.isEmpty && !subtitle.isEmpty ? " - " : "") + subtitle
        
        HStack(spacing: 20) {
            Text(displayTitle)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            extras()
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
                @Bindable var vm = vm
                
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
        .frame(height: 32)
    }
    
    // MARK: - Controls
    
    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 0) {
            leadingControls
            
            Spacer(minLength: 0)
            
            centerControls
            
            Spacer(minLength: 0)
            
            trailingControls
        }
    }
    
    @ViewBuilder
    private var leadingControls: some View {
        HStack(spacing: 20) {
            PlayerControlButton(icon: "arrow.backward", onInteract: vm.startOverlayTimer)
            {
                vm.requestDismiss()
            }
            
            PlayerControlButton(icon: "speaker.wave.2.fill",
                                isSelected: isOpen(.volume),
                                onInteract: vm.startOverlayTimer)
            {
                toggle(.volume)
            }
            .reportsPopoverAnchor(.volume)
            .popover(isPresented: presentsHere(.volume),
                     attachmentAnchor: .point(.bottom),
                     arrowEdge: .top) {
                PlayerControlsPopoverContent(vm: vm, popover: .volume)
            }
        }
    }
    
    @ViewBuilder
    private var centerControls: some View {
        HStack(spacing: 24) {
            PlayerControlButton(icon: "10.arrow.trianglehead.counterclockwise",
                                isDisabled: !vm.canSeek,
                                onInteract: vm.startOverlayTimer)
            {
                vm.jump(by: -10)
            }
            
            PlayerControlButton(icon: vm.isPlaying ? "pause.fill" : "play.fill",
                                isDisabled: !vm.canSeek,
                                onInteract: vm.startOverlayTimer)
            {
                vm.togglePlayPause()
            }
            
            PlayerControlButton(icon: "10.arrow.trianglehead.clockwise",
                                isDisabled: !vm.canSeek || (vm.isLive && vm.isAtLiveEdge),
                                onInteract: vm.startOverlayTimer)
            {
                vm.jump(by: 10)
            }
        }
    }
    
    @ViewBuilder
    private var trailingControls: some View {
        HStack(spacing: 20) {
            PlayerControlButton(icon: "captions.bubble",
                                isSelected: isOpen(.captions),
                                isDisabled: vm.selectableSubtitlesLanguages.isEmpty,
                                onInteract: vm.startOverlayTimer)
            {
                toggle(.captions)
            }
            .reportsPopoverAnchor(.captions)
            .popover(isPresented: presentsHere(.captions),
                     attachmentAnchor: .point(.trailing),
                     arrowEdge: .leading) {
                PlayerControlsPopoverContent(vm: vm, popover: .captions)
            }
            
            PlayerControlButton(icon: "globe",
                                isSelected: isOpen(.languages),
                                isDisabled: vm.selectableAudioLanguages.count <= 1,
                                onInteract: vm.startOverlayTimer)
            {
                toggle(.languages)
            }
            .reportsPopoverAnchor(.languages)
            .popover(isPresented: presentsHere(.languages),
                     attachmentAnchor: .point(.trailing),
                     arrowEdge: .leading) {
                PlayerControlsPopoverContent(vm: vm, popover: .languages)
            }
        }
    }
}


/// Where each picker's button is, in `.playerControlsHost` - for a host that presents the pickers
/// itself and so has to know where to put them.
struct PlayerControlsPopoverAnchors: PreferenceKey {
    static let defaultValue: [PlayerControlsPopover: CGRect] = [:]
    
    static func reduce(value: inout [PlayerControlsPopover: CGRect],
                       nextValue: () -> [PlayerControlsPopover: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
    /// The space `PlayerControlsPopoverAnchors` are measured in. Named by the host on whatever
    /// view it lays the controls out in.
    static var playerControlsHost: NamedCoordinateSpace { .named("PlayerControlsHost") }
}

private extension View {
    func reportsPopoverAnchor(_ popover: PlayerControlsPopover) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: PlayerControlsPopoverAnchors.self,
                                       value: [popover: proxy.frame(in: .playerControlsHost)])
            }
        }
    }
}


// MARK: - No extras

extension PlayerTransportControls where Extras == EmptyView {
    init(vm: Model, popover: Binding<PlayerControlsPopover?>? = nil) {
        self.init(vm: vm, popover: popover, extras: { EmptyView() })
    }
}
