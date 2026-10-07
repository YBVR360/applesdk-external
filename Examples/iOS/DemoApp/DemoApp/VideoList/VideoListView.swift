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
    @Environment(DirectPlayerViewModel.self) private var directPlayerVM
    
    @State private var selectedItem: Video?
    @State private var pendingSignaling: SignalingInterface?
    @State private var directPlayerVideo: Video?
    @State private var showingNetworkAlert = false
    
    @State private var columns = 1
    
    private var catalog: VideoCatalog { app.catalog }
    
    var body: some View {
        ScrollView {
            VideoLibraryView(catalog: catalog, columns: columns) { item in
                guard networkMonitor.isConnected else {
                    showingNetworkAlert = true
                    return
                }
                Task { await route(item) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 20)
        }
        .onGeometryChange(for: Int.self) { geometry in
            geometry.size.width > geometry.size.height ? 2 : 1
        } action: { columns = $0 }
            .background(Color(white: 0.28).ignoresSafeArea())
            .fullScreenCover(item: $selectedItem) { video in
                if networkMonitor.isConnected {
                    StreamView(vm: StreamViewModel(video: video,
                                                   players: app.players,
                                                   signaling: pendingSignaling,
                                                   recommendations: catalog.videos))
                }
            }
            .fullScreenCover(item: $directPlayerVideo) { _ in
                DirectPlayerFullScreenView()
            }
            .alert("No Internet Connection!", isPresented: $showingNetworkAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please check your internet connection and try again.")
            }
            .alert("Wrong file!",
                   isPresented: Binding(get: { catalog.loadFailure != nil },
                                        set: { if !$0 { catalog.clearFailure() } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(catalog.loadFailure ?? "")
            }
            .onAppear {
                AppDelegate.orientationLock = .all
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
    }
    
    /// Plays the video fullscreen through `DirectPlayer` when `PlaybackRoute` sends it there,
    /// and through `StreamView` / `YBVRPlayerManager` otherwise.
    private func route(_ video: Video) async {
        // A failed fetch still opens the player: it fetches again and, failing, shows why on
        // its own error screen, with a way back and a way to pick another.
        let signaling = try? await PlaybackRoute.fetchSignaling(for: video)
        
        switch PlaybackRoute(video: video, signaling: signaling) {
        case .directPlayer(let url, let drmKeyManager):
            directPlayerVM.title = video.name
            directPlayerVM.subtitle = ""
            await directPlayerVM.play(url: url, drmKeyManager: drmKeyManager)
            directPlayerVideo = video
        case .ybvr(let signaling):
            pendingSignaling = signaling
            selectedItem = video
        }
    }
}

#Preview {
    NavigationStack {
        VideoListView()
            .environment(NetworkMonitor())
            .environment(AppEnvironment())
            .environment(DirectPlayerViewModel())
    }
}
