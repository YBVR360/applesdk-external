//
//  DirectPlayerView.swift
//  SampleScene
//

import SwiftUI
import AVFoundation
import YBVRAppleSDK

/// A video played through `DirectPlayer` - APMP or FairPlay-protected content - fullscreen, with
/// the same controls as the YBVR player.
struct DirectPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NetworkMonitor.self) private var networkMonitor
    let vm: DirectPlaybackModel
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            PlayerLayerView(playerLayer: vm.player.playerLayer)
                .ignoresSafeArea()
                .overlay {
                    VideoOverlayView(vm: vm)
                        .ignoresSafeArea(.all, edges: [.bottom, .top])
                }
        }
        .statusBar(hidden: true)
        .onAppear {
            AppDelegate.orientationLock = .landscape
        }
        .onDisappear {
            vm.stop()
            AppDelegate.orientationLock = .all
        }
        .onChange(of: vm.player.isVideoEnded) { _, ended in
            if ended { dismiss() }
        }
        .onChange(of: vm.player.error != nil) { _, failed in
            guard failed else { return }
            fail(with: PlayerNotifications.somethingWentWrong)
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            guard !isConnected else { return }
            fail(with: PlayerNotifications.connectionLost)
        }
        .onChange(of: vm.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
    }
}

extension DirectPlayerView {
    
    /// Closes the player with `modal`, unless it is already closing for another reason.
    private func fail(with modal: PlayerNotifications.Modal) {
        guard vm.failure == nil else { return }
        vm.failure = modal
        dismiss()
    }
}

/// Hosts the player's `AVPlayerLayer`, sized to the view.
struct PlayerLayerView: UIViewRepresentable {
    let playerLayer: AVPlayerLayer
    
    final class HostView: UIView {
        var playerLayer: AVPlayerLayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let playerLayer { layer.addSublayer(playerLayer) }
                setNeedsLayout()
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer?.frame = bounds
        }
    }
    
    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.playerLayer = playerLayer
        return view
    }
    
    func updateUIView(_ uiView: HostView, context: Context) {
        if uiView.playerLayer !== playerLayer { uiView.playerLayer = playerLayer }
    }
}
