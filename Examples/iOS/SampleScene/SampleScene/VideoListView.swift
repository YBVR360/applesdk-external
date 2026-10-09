//
//  VideoListView.swift
//  SampleScene
//

import SwiftUI
import YBVRAppleSDK

/// The sample's four experiences. Each plays in the player `PlaybackRoute` picks for it.
struct VideoListView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(NetworkMonitor.self) private var networkMonitor
    
    /// The video playing through `YBVRPlayerManager`, and its player - built once, when picked.
    @State private var selectedVideo: Video?
    @State private var playerViewModel: PlayerViewModel?
    /// The video playing through `DirectPlayer`: APMP or FairPlay-protected content.
    @State private var directVideo: Video?
    @State private var directPlayback = DirectPlaybackModel()
    
    @State private var modal: PlayerNotifications.Modal?
    
    var body: some View {
        VideoLibraryView(catalog: app.catalog) { video in
            guard networkMonitor.isConnected else {
                modal = PlayerNotifications.connectionLost
                return
            }
            Task { await play(video) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(white: 0.28).ignoresSafeArea())
        .fullScreenCover(item: $selectedVideo, onDismiss: { playerViewModel = nil }) { _ in
            if let playerViewModel {
                PlayerView(vm: playerViewModel) { failure in
                    // The first reason the player stops is the one shown.
                    if modal == nil { modal = failure }
                }
            }
        }
        .fullScreenCover(item: $directVideo, onDismiss: {
            modal = directPlayback.failure
        }) { _ in
            DirectPlayerView(vm: directPlayback)
        }
        // Not over a player: it shows once the player has closed.
        .playerModal(Binding(get: { selectedVideo == nil && directVideo == nil ? modal : nil },
                             set: { modal = $0 }))
        .onAppear {
            AppDelegate.orientationLock = .all
        }
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
    
    /// Fetches the video's signaling to tell which player it needs, then opens that one. A
    /// failed fetch still opens the YBVR player, which fetches again and reports what failed.
    private func play(_ video: Video) async {
        let signaling = try? await PlaybackRoute.fetchSignaling(for: video)
        
        switch PlaybackRoute(video: video, signaling: signaling) {
        case .directPlayer(let url, let drmKeyManager):
            await directPlayback.play(video: video, url: url, drmKeyManager: drmKeyManager)
            directVideo = video
        case .ybvr(let signaling):
            playerViewModel = PlayerViewModel(video: video, signaling: signaling, players: app.players)
            selectedVideo = video
        }
    }
}
