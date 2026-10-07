//
//  DirectPlayerFullScreenView.swift
//  DemoApp
//

import SwiftUI
import AVFoundation

/// Fullscreen presentation of the shared DirectPlayer - used when a video selected from the main
/// list turns out to have DRM, so it plays like any other video (no URL field, no DRM panel).
/// Reuses `VideoOverlayView`, minus the camera map/poster the YBVR pipeline adds.
struct DirectPlayerFullScreenView: View {
    @Environment(DirectPlayerViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            PlayerLayerView(playerLayer: vm.player.playerLayer)
                .ignoresSafeArea()
                .overlay {
                    VideoOverlayView(vm: vm)
                        .opacity(vm.isOverlayVisible ? 1.0 : 0.0)
                        // Keeps the hidden overlay's buttons from swallowing the show-overlay tap.
                        .allowsHitTesting(vm.isOverlayVisible)
                }
                .onTapGesture {
                    vm.handleTap()
                }
            
            if let failure = vm.failure {
                Text(failure)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            AppDelegate.orientationLock = .landscape
            vm.startOverlayTimer()
        }
        .onChange(of: vm.isVideoEnded) { _, ended in
            if ended { vm.requestDismiss() }
        }
        .onChange(of: vm.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .onDisappear {
            vm.stop()
            AppDelegate.orientationLock = .all
        }
    }
}

// MARK: - AVPlayerLayer host view

struct PlayerLayerView: UIViewRepresentable {
    let playerLayer: AVPlayerLayer
    
    final class HostView: UIView {
        var playerLayer: AVPlayerLayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let l = playerLayer { layer.addSublayer(l) }
                setNeedsLayout()
            }
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer?.frame = bounds
        }
    }
    
    func makeUIView(context: Context) -> HostView {
        let v = HostView()
        v.playerLayer = playerLayer
        return v
    }
    
    func updateUIView(_ uiView: HostView, context: Context) {
        if uiView.playerLayer !== playerLayer { uiView.playerLayer = playerLayer }
    }
}
