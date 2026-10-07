//
//  PlayerControlsWindow.swift
//  DemoApp
//
//  Created by Niko Inas on 08.07.24.
//

import SwiftUI
import YBVRAppleSDK

/**
 The YBVR pipeline's controls, as their own window beside whatever is rendering the video.
 
 The transport row itself is `PlayerTransportControls`, shared with the Direct Player. What is
 added here is what only this pipeline has: the camera map, the ad-break bar, the surface
 switch and the recommendations panel - plus the scene plumbing that opens and closes them.
 
 Everything shown comes from `PlayerCoordinator`, so it draws the same state whether the video
 is in a window or in the immersive renderer.
 */
struct PlayerControlsWindow: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(PlayerCoordinator.self) private var coordinator
    
    @State private var showCameraMap = false
    
    /// The transport row adopts this when it appears, but it is swapped out while an ad plays -
    /// so the window applies it too, or a break opening the controls would play at full volume.
    @AppStorage("volume") private var volume: Double = 0.5
    
    private var isCameraMapAvailable: Bool {
        coordinator.overlay.isVisible && !coordinator.ads.isPlayingAd
    }
    
    private var hasCameraMap: Bool {
        (coordinator.session.presentation?.allViewPoints.count ?? 0) > 1
    }
    
    var body: some View {
        content
            .onAppear {
                guard coordinator.isSessionOnScreen else {
                    dismissWindow(id: SceneID.playerControls)
                    return
                }
                coordinator.volume = volume
                coordinator.overlay.show()
            }
            .onDisappear {
                controlsDismissed()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .inactive else { return }
                controlsDismissed()
            }
            .onChange(of: coordinator.showRecommendations) { _, visible in
                if visible {
                    openWindow(id: SceneID.recommendationsPanel)
                } else {
                    dismissWindow(id: SceneID.recommendationsPanel)
                }
                coordinator.overlay.show()
            }
            .onReceive(NotificationCenter.default.publisher(for: .videoIsReady)) { _ in
                coordinator.overlay.show()
            }
    }
    
    // MARK: - Layout
    
    @ViewBuilder
    private var content: some View {
        Group {
            // An ad break owns the screen: seeking and camera changes are meaningless during
            // one, so the transport row gives way to the ad's own bar.
            if coordinator.ads.isPlayingAd {
                AdPlaybackBar(harness: coordinator.ads, onBack: coordinator.requestDismiss)
                    .frame(width: 658)
                    .glassBackgroundEffect()
            } else {
                PlayerTransportControls(vm: coordinator) {
                    pipelineExtras
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.ads.isPlayingAd)
        .ornament(visibility: isCameraMapAvailable && hasCameraMap ? .visible : .hidden,
                  attachmentAnchor: .parent(.top),
                  contentAlignment: .bottom)
        {
            CameraMapToolbar(isMapOpen: $showCameraMap,
                             onInteract: coordinator.startOverlayTimer)
            .padding(8)
        }
        .ornament(visibility: isCameraMapAvailable && showCameraMap ? .visible : .hidden,
                  attachmentAnchor: .parent(.bottom),
                  contentAlignment: .top)
        {
            CameraMapView()
                .cameraMap(session: coordinator.session, select: coordinator.selectViewPoint)
                .padding(12)
        }
    }
    
    /// The buttons only the YBVR pipeline has, handed to the shared transport row.
    @ViewBuilder
    private var pipelineExtras: some View {
        PlayerControlButton(icon: coordinator.surface == .window
                            ? "visionpro"
                            : "rectangle.on.rectangle",
                            isDisabled: coordinator.isSwitchingSurface,
                            onInteract: coordinator.startOverlayTimer) {
            Task { await switchSurface() }
        }
        
        PlayerControlButton(icon: "rectangle.stack.badge.play.fill",
                            isSelected: coordinator.showRecommendations,
                            onInteract: coordinator.startOverlayTimer) {
            coordinator.showRecommendations.toggle()
        }
    }
    
    // MARK: - Actions
    
    /// Moves the session between the window player and the immersive one, keeping the video
    /// where it was. The coordinator captures what is playing; the scenes are swapped here,
    /// and the new one puts it back once its player is streaming.
    private func switchSurface() async {
        let target = coordinator.surface.other
        guard coordinator.beginSurfaceSwitch(to: target) else { return }
        
        switch target {
        case .window:
            await dismissImmersiveSpace()
            openWindow(id: coordinator.windowSceneId)
        case .immersive:
            guard case .opened = await openImmersiveSpace(id: coordinator.immersiveSceneId) else {
                // The old player is already gone, so there is nothing to fall back to.
                coordinator.end()
                openWindow(id: SceneID.startingScene)
                return
            }
        }
        
        coordinator.overlay.show()
    }
    
    private func controlsDismissed() {
        guard !coordinator.isSwitchingSurface else { return }
        
        coordinator.overlay.hide()
        
        dismissWindow(id: SceneID.recommendationsPanel)
        coordinator.showRecommendations = false
    }
}

#Preview {
    PlayerControlsWindow()
        .environment(PlayerCoordinator(environment: AppEnvironment()))
}
