//
//  PlayerView.swift
//  SampleScene
//

import SwiftUI
import YBVRAppleSDK

/// The video fullscreen, with the controls always on screen over it, and the control room's
/// grid beside it while the control room is playing.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NetworkMonitor.self) private var networkMonitor
    @State var vm: PlayerViewModel
    
    /// Hands a blocking notification to the list, which shows it once the player has closed.
    var onFailure: (PlayerNotifications.Modal) -> Void = { _ in }
    
    @State private var videoSize: CGSize = UIScreen.main.bounds.size
    
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            ZStack(alignment: .topLeading) {
                // The control room grid goes beside the video on a phone, below it on an iPad.
                if !isIPad {
                    HStack(spacing: 0) {
                        layout
                    }
                } else {
                    VStack {
                        layout
                    }
                }
            }
            
            if vm.session.isLoading {
                loadingCover
            }
        }
        .overlay(alignment: .top) {
            PlayerNoticeBanner(notice: vm.notice)
                .padding(.top, 16)
        }
        .animation(.easeInOut, value: vm.session.isLoading)
        .animation(.easeInOut, value: vm.isMultiviewVisible)
        .animation(.easeInOut, value: vm.notice.message)
        .statusBar(hidden: true)
        .onAppear {
            AppDelegate.orientationLock = .landscape
        }
        .task {
            await vm.start()
        }
        .onDisappear {
            vm.stop()
        }
        .onChange(of: vm.session.camera) { oldValue, newValue in
            vm.isCameraMapOpen = false
        }
        .onChange(of: vm.failure) { _, failure in
            guard failure != nil else { return }
            onFailure(PlayerNotifications.somethingWentWrong)
            vm.requestDismiss()
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            guard !isConnected else { return }
            onFailure(PlayerNotifications.connectionLost)
            vm.requestDismiss()
        }
        .onChange(of: vm.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            AppDelegate.orientationLock = .all
            dismiss()
        }
    }
    
    @ViewBuilder
    private var layout: some View {
        if let player = vm.player {
            Color.clear
                .overlay {
                    GeometryVideoView(sc: player.getSurfaceController())
                        .frame(height: videoSize.width / Ratios.videoRatio)
                        .ignoresSafeArea(.all, edges: [.bottom, .top])
                        .background {
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: VideoSizePreferenceKey.self, value: geo.size)
                            }
                        }
                        .onPreferenceChange(VideoSizePreferenceKey.self) { size in
                            videoSize = size
                        }
                }
                .overlay {
                    if vm.isShowingImmersiveContent {
                        arrowsLayout
                    }
                }
                .overlay {
                    VideoOverlayView(vm: vm) {
                        VStack(spacing: 12) {
                            if vm.isCameraMapOpen && vm.hasCameraMap {
                                FittedCameraMapView()
                                    .cameraMap(session: vm.session) { viewPoint in
                                        await vm.select(viewPoint: viewPoint)
                                    }
                                    .transition(.opacity)
                            }
                            
                            ActionBar(actions: actions)
                        }
                        .animation(.easeInOut(duration: 0.2), value: vm.isCameraMapOpen)
                        .animation(.easeInOut(duration: 0.2), value: vm.notice.message)
                    }
                    .ignoresSafeArea(.all, edges: [.bottom, .top])
                    .padding(.trailing, (!isIPad && vm.isMultiviewVisible && vm.controlRoomSelector != nil) ? 25 : 0 )
                    .padding(.bottom, (isIPad && vm.isMultiviewVisible && vm.controlRoomSelector != nil) ? 25 : 0 )
                }
        }
        
        controlRoomSidePanel
    }
    
    @ViewBuilder
    private var controlRoomSidePanel: some View {
        if vm.isMultiviewVisible, let selector = vm.controlRoomSelector {
            if !isIPad {
                HStack(spacing: 0) {
                    Button {
                        withAnimation {
                            vm.isFullScreen.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundStyle(Color.white)
                            .rotationEffect(.degrees(vm.isFullScreen ? -180 : 0))
                    }
                    if !vm.isFullScreen {
                        ControlRoomSelectorView(vm: selector, maxSize: vm.controlRoomMaxSize)
                            .id(ObjectIdentifier(selector)) // Required for SwiftUI to update
                            .transition(.move(edge: .trailing).combined(with: .blurReplace))
                    }
                }
                .frame(maxHeight: .infinity)
                .background {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                }
                .padding(.leading, -25)
                .transition(.move(edge: .trailing).combined(with: .blurReplace))
            } else {
                VStack(spacing: 0) {
                    Button {
                        withAnimation {
                            vm.isFullScreen.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundStyle(Color.white)
                            .rotationEffect(.degrees(vm.isFullScreen ? -180 : 0))
                    }
                    if !vm.isFullScreen {
                        ControlRoomSelectorView(vm: selector, maxSize: vm.controlRoomMaxSize)
                            .id(ObjectIdentifier(selector)) // Required for SwiftUI to update
                            .transition(.move(edge: .bottom).combined(with: .blurReplace))
                    }
                }
                .frame(maxWidth: .infinity)
                .background {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                }
                .padding(.top, -25)
                .transition(.move(edge: .bottom).combined(with: .blurReplace))
            }
        }
    }
    
    @ViewBuilder
    private var arrowsLayout: some View {
        HStack(spacing: 0) {
            Button {
                vm.session.rotate(radians: .pi / 4)
            } label: {
                Image(systemName: "chevron.left")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            
            Spacer(minLength: 0)
            
            Button {
                vm.session.rotate(radians: -.pi / 4)
            } label: {
                Image(systemName: "chevron.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
                    .foregroundStyle(Color.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var actions: [ActionBar.Action] {
        var actions: [ActionBar.Action] = []
        
        if vm.hasCameraMap {
            actions.append(.init(title: "Camera Map", icon: "mappin.and.ellipse",
                                 isActive: vm.isCameraMapOpen) {
                vm.isCameraMapOpen.toggle()
            })
        }
        if vm.isShowingImmersiveContent {
            actions.append(.init(title: "Recenter", icon: "scope") {
                vm.recenter()
            })
        }
        return actions
    }
}

// MARK: - Loading

extension PlayerView {
    
    @ViewBuilder
    private var loadingCover: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Loading…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(vm.session.video?.name ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .transition(.opacity)
    }
}

/// The video's laid out size, which its height is derived from.
private struct VideoSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    }
}
