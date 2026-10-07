//
//  StreamCameraOverlayView.swift
//  DemoApp
//
//  Created by Peter Angiuoli on 9/2/26.
//

import SwiftUI
import YBVRAppleSDK

/**
 The camera controls above the transport bar, the part of the stream overlay that only makes
 sense for the multi-camera YBVR pipeline. Passed to `VideoOverlayView` by `StreamView`.
 
 The same pieces as on visionOS: `CameraMapToolbar` to open the map and act on the camera, and
 `CameraMapView` above it once opened.
 */
struct StreamCameraOverlayView: View {
    
    let vm: StreamViewModel
    
    @State private var isMapOpen = false
    
    /// More than one view point to choose between - a single camera has nothing to map.
    private var hasCameraMap: Bool {
        (vm.presentation?.allViewPoints.count ?? 0) > 1
    }
    
    /// Recenter, only for immersive content - a flat feed has no view to recentre - or, while the
    /// control room's multiview is on screen, the switch between it and one feed at full screen.
    private var cameraActions: [CameraMapToolbar.Action] {
        if vm.isCameraSelectorAppeared {
            return [.init(title: "Full Screen",
                          icon: vm.isFullScreen
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right",
                          isSelected: vm.isFullScreen) {
                vm.isFullScreen.toggle()
            }]
        }
        guard vm.isShowingImmersiveContent else { return [] }
        return [.init(title: "Recenter", icon: "scope") {
            vm.didTapRecenter()
        }]
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if isMapOpen && hasCameraMap {
                // Fitted to the room left above the toolbar: a phone has less of it than the
                // map's own size, and a map that did not shrink would push the rest away.
                FittedCameraMapView()
                    .cameraMap(session: vm.session) { viewPoint in
                        // Through the presentation, as the rest of the iOS demo selects: the
                        // stream view reacts to it and plays the camera.
                        vm.presentation?.setSelectedViewPoint(viewPoint)
                        vm.startOverlayTimer()
                    }
                    .transition(.opacity)
            }
            
            // Left off altogether when it would carry nothing - flat content with no map.
            if hasCameraMap || !cameraActions.isEmpty {
                CameraMapToolbar(isMapOpen: hasCameraMap ? $isMapOpen : nil,
                                 actions: cameraActions,
                                 onInteract: vm.startOverlayTimer)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isMapOpen)
        .onChange(of: hasCameraMap) { _, hasMap in
            // Content switched to one with nothing to map: the map has nothing left to show.
            if !hasMap { isMapOpen = false }
        }
        .onChange(of: vm.player?.selectedControlRoomCameraValue) { _, newValue in
            if newValue != nil {
                // For the play button's transition between the control room and ICC buttons.
                vm.presentation?.setSelectedViewPoint(nil)
                vm.didTapRecenter()
            } else {
                // Lets the camera map selector and the fullscreen button coexist.
                vm.isFullScreen = false
            }
        }
        .onChange(of: vm.presentation?.selectedViewPoint) { _, newValue in
            // Covers both the control room <-> ICC transition and picking between control
            // room cameras.
            guard newValue != nil, let presentation = vm.presentation else { return }
            vm.isCameraSelectorAppeared = presentation.controlRoomViewPoint != nil
            && presentation.selectedViewPoint == presentation.controlRoomViewPoint
        }
    }
}

#Preview(traits: .landscapeLeft) {
    StreamCameraOverlayView(vm: StreamViewModel(video: Video.example))
        .background(Color.gray)
}
