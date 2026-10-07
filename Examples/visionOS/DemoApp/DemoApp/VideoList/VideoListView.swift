//
//  VideoListView.swift
//  DemoApp
//
//  Created by Niko Inas on 21.12.23.
//

import SwiftUI
import YBVRAppleSDK

struct VideoListView: View {
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AppEnvironment.self) private var app
    @Environment(PlayerCoordinator.self) private var coordinator
    @Environment(DirectPlayerViewModel.self) private var directPlayerVM
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    
    @State private var showingNetworkAlert = false
    @State private var videoAwaitingAdSetup: Video?
    @State private var isOpeningScene = false
    
    var body: some View {
        ScrollView {
            VideoLibraryView(catalog: app.catalog, columns: 2) { item in
                guard networkMonitor.isConnected else {
                    showingNetworkAlert = true
                    return
                }
                videoAwaitingAdSetup = item
            }
            .padding(28)
        }
        .frame(width: 720, height: 600)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .sheet(item: $videoAwaitingAdSetup) { video in
            AdSetupSheet(
                harness: coordinator.ads,
                video: video,
                onPlay: {
                    videoAwaitingAdSetup = nil
                    Task { await route(video) }
                },
                onCancel: {
                    videoAwaitingAdSetup = nil
                }
            )
        }
        .alert("No Internet Connection", isPresented: $showingNetworkAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please check your internet connection and try again.")
        }
        .alert("Can't play this video",
               isPresented: Binding(get: { coordinator.error != nil },
                                    set: { if !$0 { coordinator.error = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(coordinator.error?.localizedDescription ?? "")
        }
        .padding(.horizontal, 10.0)
        .padding(.top, 20)
        .navigationTitle("List of Videos")
    }
    
    /// Plays the video in `DirectPlayerImmersiveScene` through `DirectPlayer` when
    /// `PlaybackRoute` sends it there, and through the `YBVRPlayerManager` pipeline otherwise.
    private func route(_ video: Video) async {
        guard !isOpeningScene, !coordinator.isPresenting else { return }
        isOpeningScene = true
        defer { isOpeningScene = false }
        
        let signaling: SignalingInterface?
        do {
            signaling = try await PlaybackRoute.fetchSignaling(for: video)
        } catch {
            // Nothing to open a scene for; the alert below shows why.
            coordinator.error = error
            return
        }
        
        switch PlaybackRoute(video: video, signaling: signaling) {
        case .directPlayer(let url, let drmKeyManager):
            directPlayerVM.title = video.name
            directPlayerVM.subtitle = ""
            await directPlayerVM.play(url: url, drmKeyManager: drmKeyManager)
            await openImmersiveSpace(id: DirectPlayerImmersiveScene.id)
            
        case .ybvr(let signaling):
            coordinator.begin(video: video, signaling: signaling)
            
            if case .opened = await openImmersiveSpace(id: coordinator.immersiveSceneId) {
                return
            }
            
            // The space refused to open, so nothing is going to render the session.
            coordinator.end()
        }
    }
}

#Preview {
    let app = AppEnvironment()
    
    VideoListView()
        .environment(NetworkMonitor())
        .environment(app)
        .environment(PlayerCoordinator(environment: app))
        .environment(DirectPlayerViewModel())
}
