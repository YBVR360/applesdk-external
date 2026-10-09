//
//  DirectPlayerImmersiveScene.swift
//  SampleScene
//

import SwiftUI
import RealityKit
import AVFoundation
import YBVRAppleSDK

/// The immersive space for content played through `DirectPlayer`: APMP content, which RealityKit
/// renders from its own projection metadata, and FairPlay-protected content.
struct DirectPlayerImmersiveScene: SwiftUI.Scene {
    static let id = "DirectPlayerImmersiveScene"
    
    var body: some SwiftUI.Scene {
        ImmersiveSpace(id: Self.id) {
            DirectPlayerImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

/**
 Shows the player's video on a RealityKit `VideoPlayerComponent`.
 
 Whether it wraps around the viewer depends on the stream's own projection metadata: immersive
 content is left at the origin, centred on the viewer, and flat content is placed on a screen
 in front of them. The controls are a window of their own, open while the video plays; a pinch
 anywhere brings them back once closed.
 */
private struct DirectPlayerImmersiveView: View {
    @Environment(DirectPlaybackModel.self) private var player
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var videoEntity = Entity()
    /// A box of thin walls around the viewer, so a pinch anywhere lands on something.
    @State private var pinchTarget: Entity = {
        let size: Float = 10
        let walls: [ShapeResource] = [0, 1, 2].flatMap { axis in
            [Float(-1), 1].map { side in
                var extent = SIMD3<Float>(repeating: size)
                extent[axis] = 0.01
                var offset = SIMD3<Float>.zero
                offset[axis] = size / 2 * side
                return ShapeResource.generateBox(size: extent).offsetBy(translation: offset)
            }
        }
        let entity = Entity()
        entity.components.set(CollisionComponent(shapes: walls, mode: .trigger))
        entity.components.set(InputTargetComponent())
        entity.position = [0, 1, 0]
        return entity
    }()
    
    private static let flatScreenPosition: SIMD3<Float> = [0, 1.5, -2]
    
    var body: some View {
        RealityView { content in
            content.add(videoEntity)
            content.add(pinchTarget)
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { _ in
                    if !player.isControlsWindowOpen {
                        openWindow(id: SceneID.directPlayerControls)
                    }
                }
        )
        .onChange(of: player.player.status != nil, initial: true) { _, isReady in
            Task { await showVideo(isReady) }
        }
        .onAppear {
            dismissWindow(id: SceneID.videoList)
            openWindow(id: SceneID.directPlayerControls)
        }
        .onChange(of: player.player.isVideoEnded) { _, ended in
            if ended { close() }
        }
        .onChange(of: player.player.error != nil) { _, failed in
            guard failed else { return }
            fail(with: PlayerNotifications.somethingWentWrong)
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            guard !isConnected else { return }
            fail(with: PlayerNotifications.connectionLost)
        }
        .onChange(of: player.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { close() }
        }
        .onDisappear {
            videoEntity.components.remove(VideoPlayerComponent.self)
            player.stop()
            dismissWindow(id: SceneID.directPlayerControls)
            openWindow(id: SceneID.videoList)
        }
    }
    
    private func close() {
        Task { await dismissImmersiveSpace() }
    }
    
    /// Closes the space with `modal`, unless it is already closing for another reason.
    private func fail(with modal: PlayerNotifications.Modal) {
        guard player.failure == nil else { return }
        player.failure = modal
        close()
    }
    
    /// Puts the video on `videoEntity` once the player has an item, placed for its projection.
    private func showVideo(_ isReady: Bool) async {
        let avPlayer = player.player.avPlayer
        guard isReady, let asset = avPlayer.currentItem?.asset else {
            videoEntity.components.remove(VideoPlayerComponent.self)
            return
        }
        
        videoEntity.position = await Self.isFlat(asset) ? Self.flatScreenPosition : .zero
        
        // An AVPlayer feeds one video target at a time: RealityKit renders it here, not the
        // `AVPlayerLayer` iOS uses.
        player.player.playerLayer.player = nil
        videoEntity.components.set(VideoPlayerComponent(avPlayer: avPlayer))
    }
    
    /// Whether the video's own metadata leaves it a flat picture, rather than one around the viewer.
    private static func isFlat(_ asset: AVAsset) async -> Bool {
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let format = try? await track.load(.formatDescriptions).first,
              let kind = CMFormatDescriptionGetExtension(
                format, extensionKey: kCMFormatDescriptionExtension_ProjectionKind) else {
            return true
        }
        
        let immersiveKinds: [CFString] = [
            kCMFormatDescriptionProjectionKind_Equirectangular,
            kCMFormatDescriptionProjectionKind_HalfEquirectangular,
            kCMFormatDescriptionProjectionKind_ParametricImmersive,
            kCMFormatDescriptionProjectionKind_AppleImmersiveVideo,
        ]
        return !immersiveKinds.contains { CFEqual($0, kind) }
    }
}
