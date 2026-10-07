//
//  DirectPlayerImmersiveScene.swift
//  DemoApp
//

import SwiftUI
import RealityKit
import AVFoundation
import CoreMedia
import YBVRAppleSDK

/// The immersive space for content played through `DirectPlayer`: DRM-protected content, and
/// APMP content, which RealityKit renders from its own projection metadata.
struct DirectPlayerImmersiveScene: SwiftUI.Scene {
    static let id = "DirectPlayerImmersiveScene"
    
    var body: some SwiftUI.Scene {
        ImmersiveSpace(id: Self.id) {
            DirectPlayerImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed, .full)
        .immersiveEnvironmentBehavior(.coexist)
        .immersiveContentBrightness(.automatic)
        .upperLimbVisibility(.automatic)
    }
}

/// Projects the Direct Player video onto a RealityKit VideoPlayerComponent.
/// Whether it actually wraps around the viewer (vs. showing as a flat panel) depends
/// entirely on the stream's own embedded projection metadata - detected below via the
/// video track's `kCMFormatDescriptionExtension_ProjectionKind`. Only flat/rectilinear
/// content gets manually placed in front of the viewer; genuinely immersive content is
/// left at the world origin so its sphere stays centered on the viewer.
struct DirectPlayerImmersiveView: View {
    @Environment(DirectPlayerViewModel.self) private var vm
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var videoEntity = Entity()
    /// `true` while the system moves the video between its immersive viewing modes, which sends
    /// the scene to the background without the viewer having left it.
    @State private var isImmersiveTransitionPending = false
    /// Bumped on every status change, so a run that has suspended can tell it was superseded.
    @State private var componentGeneration = 0
    /// The picker the controls have open. Nothing presents in this space. So each picker is
    /// an attachment of its own, shown above the controls while it is open.
    @State private var openPopover: PlayerControlsPopover?
    /// The picker buttons' frames, and the size of the controls attachment they are measured in,
    /// in points - reported by the controls, so the pickers follow the actual layout.
    @State private var popoverAnchors: [PlayerControlsPopover: CGRect] = [:]
    @State private var controlsSize: CGSize = .zero
    /// Invisible target so a pinch anywhere re-shows the controls, and closes an open picker.
    /// Six thin walls boxing the viewer.
    @State private var gestureReceiver: ModelEntity = {
        let halfSize: Float = 5
        let thickness: Float = 0.01
        let walls: [ShapeResource] = [0, 1, 2].flatMap { axis -> [ShapeResource] in
            var size = SIMD3<Float>(repeating: halfSize * 2)
            size[axis] = thickness
            return [Float(-1), 1].map { side -> ShapeResource in
                var offset = SIMD3<Float>.zero
                offset[axis] = halfSize * side
                return .generateBox(size: size).offsetBy(translation: offset)
            }
        }
        
        let entity = ModelEntity()
        entity.collision = CollisionComponent(shapes: walls, mode: .trigger)
        entity.components.set(InputTargetComponent())
        entity.position = [0, 1, 0]
        return entity
    }()
    
    private static let flatScreenPosition: SIMD3<Float> = [0, 1.5, -2]
    private static let immersiveOriginPosition: SIMD3<Float> = [0, 0, 0]
    private static let controlsPosition: SIMD3<Float> = [0, 0.9, -1.5]
    
    var body: some View {
        RealityView { content, attachments in
            content.add(videoEntity)
            content.add(gestureReceiver)
            subscribeToEvents(content: content)
            if let controlsEntity = attachments.entity(for: Self.controlsAttachmentID) {
                controlsEntity.position = Self.controlsPosition
                content.add(controlsEntity)
            }
            for popover in PlayerControlsPopover.allCases {
                if let popoverEntity = attachments.entity(for: Self.attachmentID(for: popover)) {
                    popoverEntity.isEnabled = false
                    content.add(popoverEntity)
                }
            }
        } update: { content, attachments in
            guard let controlsEntity = attachments.entity(for: Self.controlsAttachmentID) else { return }
            
            controlsEntity.isEnabled = vm.isOverlayVisible
            for popover in PlayerControlsPopover.allCases {
                guard let popoverEntity = attachments.entity(for: Self.attachmentID(for: popover)) else { continue }
                let position = popoverAnchors[popover].flatMap {
                    Self.popoverPosition(for: popover,
                                         entity: popoverEntity,
                                         button: $0,
                                         controlsSize: controlsSize,
                                         controls: controlsEntity)
                }
                popoverEntity.isEnabled = controlsEntity.isEnabled && openPopover == popover && position != nil
                if let position {
                    popoverEntity.position = position
                }
            }
        } attachments: {
            Attachment(id: Self.controlsAttachmentID) {
                VStack(spacing: 12) {
                    if let failure = vm.failure {
                        Text(failure)
                            .font(.callout)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: 658)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    }
                    
                    PlayerTransportControls(vm: vm, popover: $openPopover)
                }
                .opacity(vm.isOverlayVisible ? 1 : 0)
                .allowsHitTesting(vm.isOverlayVisible)
                .coordinateSpace(.playerControlsHost)
                .onPreferenceChange(PlayerControlsPopoverAnchors.self) { popoverAnchors = $0 }
                .onGeometryChange(for: CGSize.self) { $0.size } action: { controlsSize = $0 }
            }
            
            ForEach(PlayerControlsPopover.allCases, id: \.self) { popover in
                Attachment(id: Self.attachmentID(for: popover)) {
                    PlayerControlsPopoverContent(vm: vm, popover: popover)
                        .fixedSize()
                        .glassBackgroundEffect()
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    // A pinch past the controls closes an open picker, as it would a popover.
                    if value.entity === gestureReceiver {
                        openPopover = nil
                    }
                    vm.startOverlayTimer()
                }
        )
        // Keyed on having a status at all.
        .onChange(of: vm.player.status != nil, initial: true) { _, isReady in
            componentGeneration += 1
            let generation = componentGeneration
            Task { await updateComponent(isReady: isReady, generation: generation) }
        }
        .onAppear {
            dismissWindow(id: SceneID.startingScene)
            vm.startOverlayTimer()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background, !isImmersiveTransitionPending else { return }
            vm.player.pause()
        }
        .onChange(of: vm.isVideoEnded) { _, ended in
            guard ended else { return }
            vm.requestDismiss()
        }
        .onChange(of: vm.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            Task { await dismissImmersiveSpace() }
        }
        .onDisappear {
            // Whether the space was closed via our own button below or the system
            videoEntity.components.remove(VideoPlayerComponent.self)
            openPopover = nil
            vm.stop()
            openWindow(id: SceneID.startingScene)
        }
    }
    
    private static let controlsAttachmentID = "DirectPlayerImmersiveView.controls"
    
    private static func attachmentID(for popover: PlayerControlsPopover) -> String {
        "DirectPlayerImmersiveView.popover.\(popover)"
    }
    
    /// Where the picker for `popover` sits, matching where the controls' own popovers open in
    /// a window. A little nearer than the panel so it is never behind it. In the controls' parent
    /// space, as the pickers are their siblings. `nil` until the layout has been measured.
    ///
    /// - Parameters:
    ///   - button: The button's frame, in points, within the controls attachment.
    ///   - controlsSize: The controls attachment's size, in points. Against its width in meters
    ///     it gives the scale; the attachment entity is centered on the view.
    private static func popoverPosition(for popover: PlayerControlsPopover,
                                        entity: Entity,
                                        button: CGRect,
                                        controlsSize: CGSize,
                                        controls: Entity) -> SIMD3<Float>? {
        let panel = controls.visualBounds(relativeTo: controls)
        guard controlsSize.width > 0, !panel.isEmpty else { return nil }
        
        let metersPerPoint = (panel.max.x - panel.min.x) / Float(controlsSize.width)
        // SwiftUI measures from the top-left corner, downwards; the entity from its center, up.
        let buttonCenter = SIMD2<Float>(Float(button.midX - controlsSize.width / 2),
                                        Float(controlsSize.height / 2 - button.midY)) * metersPerPoint
        let buttonHalfSize = SIMD2<Float>(Float(button.width), Float(button.height)) / 2 * metersPerPoint
        let size = entity.visualBounds(relativeTo: entity).extents
        let gap = 8 * metersPerPoint
        
        let center: SIMD2<Float> = switch popover {
        case .volume:
            [buttonCenter.x, buttonCenter.y - buttonHalfSize.y - gap - size.y / 2]
        case .captions, .languages:
            [buttonCenter.x + buttonHalfSize.x + gap + size.x / 2, buttonCenter.y]
        }
        return controls.position + [center.x, center.y, panel.max.z + 0.01]
    }
    
    /// Brings the controls back once the video is on screen, and after the system has moved it
    /// between viewing modes.
    private func subscribeToEvents(content: RealityViewContent) {
        _ = content.subscribe(to: VideoPlayerEvents.ImmersiveViewingModeWillTransition.self,
                              on: videoEntity) { _ in
            isImmersiveTransitionPending = true
        }
        
        _ = content.subscribe(to: VideoPlayerEvents.ImmersiveViewingModeDidTransition.self,
                              on: videoEntity) { _ in
            isImmersiveTransitionPending = false
            vm.startOverlayTimer()
        }
        
        _ = content.subscribe(to: VideoPlayerEvents.RenderingStatusDidChange.self,
                              on: videoEntity) { event in
            guard event.currentStatus == .ready else { return }
            vm.startOverlayTimer()
        }
    }
    
    /// Attaches the video to `videoEntity`, or takes it off when there is nothing to show.
    private func updateComponent(isReady: Bool, generation: Int) async {
        // Read the player directly, never through `playerLayer`: the layer is handed the
        // player only so iOS can render it, and below it gives the player up entirely.
        let avPlayer = vm.player.avPlayer
        
        guard isReady, let asset = avPlayer.currentItem?.asset else {
            guard generation == componentGeneration else { return }
            videoEntity.components.remove(VideoPlayerComponent.self)
            return
        }
        
        let isFlat = await Self.isFlatProjection(asset: asset)
        guard generation == componentGeneration else { return }
        
        videoEntity.position = isFlat ? Self.flatScreenPosition : Self.immersiveOriginPosition
        
        // An AVPlayer feeds one video target at a time. `DirectPlayer` always builds an
        // `AVPlayerLayer` because iOS renders through it, but here RealityKit does - and while
        // the layer still holds the player, which of the two gets the frames is a race.
        vm.player.playerLayer.player = nil
        
        if videoEntity.components[VideoPlayerComponent.self]?.avPlayer !== avPlayer {
            videoEntity.components.set(VideoPlayerComponent(avPlayer: avPlayer))
        }
    }
    
    private static func isFlatProjection(asset: AVAsset) async -> Bool {
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let formatDescription = try? await track.load(.formatDescriptions).first,
              let projectionKind = CMFormatDescriptionGetExtension(
                formatDescription,
                extensionKey: kCMFormatDescriptionExtension_ProjectionKind
              ) else {
            return true
        }
        
        let immersiveKinds: [CFString] = [
            kCMFormatDescriptionProjectionKind_Equirectangular,
            kCMFormatDescriptionProjectionKind_HalfEquirectangular,
            kCMFormatDescriptionProjectionKind_ParametricImmersive,
            kCMFormatDescriptionProjectionKind_AppleImmersiveVideo
        ]
        return !immersiveKinds.contains { CFEqual($0, (projectionKind as! CFString)) }
    }
}
