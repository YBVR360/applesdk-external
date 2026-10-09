//
//  VideoListView.swift
//  SampleScene
//

import SwiftUI
import YBVRAppleSDK

/// The sample's four experiences. Each plays in the player `PlaybackRoute` picks for it.
struct VideoListView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(PlayerModel.self) private var player
    @Environment(DirectPlaybackModel.self) private var directPlayback
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var connectionModal: PlayerNotifications.Modal?
    @State private var isOpening = false
    
    var body: some View {
        VideoLibraryView(catalog: app.catalog) { video in
            guard networkMonitor.isConnected else {
                connectionModal = PlayerNotifications.connectionLost
                return
            }
            Task { await play(video) }
        }
        .padding(28)
        .disabled(isOpening)
        .frame(width: 720, height: 600)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .playerModal($connectionModal)
        // Why the last video stopped, once its space has closed.
        .playerModal(Binding(get: { player.failure }, set: { player.failure = $0 }))
        .playerModal(Binding(get: { directPlayback.failure }, set: { directPlayback.failure = $0 }))
        .onAppear {
            // Whatever the last video left open goes away with it.
            dismissWindow(id: SceneID.playerControls)
            dismissWindow(id: SceneID.directPlayerControls)
        }
    }
    
    /// Fetches the video's signaling to tell which player it needs, then opens that one's
    /// immersive space. A failed fetch still opens the YBVR player, which fetches again and
    /// reports what failed.
    private func play(_ video: Video) async {
        guard !isOpening, !player.isSessionOnScreen else { return }
        isOpening = true
        defer { isOpening = false }
        
        let signaling = try? await PlaybackRoute.fetchSignaling(for: video)
        
        switch PlaybackRoute(video: video, signaling: signaling) {
        case .directPlayer(let url, let drmKeyManager):
            await directPlayback.play(video: video, url: url, drmKeyManager: drmKeyManager)
            if case .opened = await openImmersiveSpace(id: DirectPlayerImmersiveScene.id) {
                return
            }
            directPlayback.stop()
            
        case .ybvr(let signaling):
            player.begin(video: video, signaling: signaling)
            if case .opened = await openImmersiveSpace(id: ImmersivePlayerScene.id) {
                return
            }
            player.end()
        }
    }
}
