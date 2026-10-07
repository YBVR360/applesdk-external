//
//  StreamView.swift
//  DemoApp
//
//  Created by Niko Inas on 29.01.24.
//

import SwiftUI
import YBVRAppleSDK

struct StreamView: View {
    @Environment(\.dismiss) private var dismiss
    @State var vm: StreamViewModel
    
    @State private var videoSize: CGSize = UIScreen.main.bounds.size
    
    private var isContentOverlayVisible: Bool {
        vm.overlay.isVisible && !vm.ads.isPlayingAd
    }
    
    private var isAnyPanelVisible: Bool {
        vm.isRecommendationsVisible || vm.isAdSchedulerVisible
    }
    
    private var showCRSelector: Bool {
        vm.isCameraSelectorAppeared && !vm.isFullScreen && !vm.ads.isPlayingAd
    }
    
    private var showsRotationArrows: Bool { vm.isShowingImmersiveContent }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            ZStack(alignment: .topLeading) {
                // For Video & VideoOverlay interaction with CameraSelector
                if !isIPad { // For iPhone or compact size class
                    HStack(spacing: 5) {
                        commonVideoLayout
                    }
                } else { // For iPad or regular size class
                    VStack {
                        commonVideoLayout
                    }
                }
            }
            
            if showsRotationArrows {
                arrowsLayout
            }
            
            if vm.ads.isPlayingAd {
                AdOverlayView(vm: vm)
                    .transition(.opacity)
            }
            
            if let failure = vm.session.failure {
                loadFailureCover(failure)
            } else if vm.session.isLoading && !vm.ads.isPlayingAd {
                loadingCover
            }
            
            // Above the failure cover: "Pick another" opens the gate from there.
            if vm.isAwaitingAdSetup {
                adSetupGate(for: vm.video,
                            onPlay: { Task { await startFromGate() } },
                            onCancel: { vm.shouldDismiss = true })
            } else if let next = vm.pendingSwitch {
                adSetupGate(for: next,
                            onPlay: { Task { await vm.confirmSwitch() } },
                            onCancel: { vm.cancelSwitch() })
            }
            
            testHarnessPanels
        }
        .animation(.easeInOut, value: vm.session.isLoading)
        .animation(.easeInOut, value: vm.pendingSwitch)
        .animation(.easeInOut, value: vm.session.failure)
        .animation(.easeInOut, value: vm.ads.isPlayingAd)
        .animation(.easeInOut, value: vm.ads.isPreparingAdBreak)
        .animation(.easeInOut, value: showCRSelector)
        .statusBar(hidden: true)
        .onAppear {
            AppDelegate.orientationLock = .landscape
        }
        .task {
            guard !vm.isAwaitingAdSetup else { return }
            await vm.startStream()
        }
        .onDisappear {
            vm.stop()
        }
        .onChange(of: vm.player?.selectedControlRoomCameraValue) { _, camera in
            guard let camera else { return }
            Task { await vm.didSelect(camera: camera) }
        }
        .onChange(of: vm.presentation?.selectedViewPoint) { _, viewPoint in
            guard let viewPoint else { return }
            Task { await vm.didSelect(viewPoint: viewPoint) }
        }
        .onChange(of: vm.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            AppDelegate.orientationLock = .all
            dismiss()
        }
    }
    
    @ViewBuilder
    private var commonVideoLayout: some View {
        if let player = vm.player {
            Color.clear
                .overlay {
                    GeometryVideoView(sc: player.getSurfaceController())
                        .frame(height: videoSize.width / Ratios.videoRatio)
                        .ignoresSafeArea(.all, edges: [.bottom, .top])
                        .background {
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ViewPreferenceKey.self, value: geo.size)
                            }
                        }
                        .onPreferenceChange(ViewPreferenceKey.self) { size in
                            videoSize = size
                        }
                }
                .overlay {
                    ZStack(alignment: .bottom) {
                        subtitleOverlay
                        
                        VideoOverlayView(vm: vm) {
                            StreamCameraOverlayView(vm: vm)
                        }
                        .onAppear {
                            vm.overlay.show()
                        }
                        .opacity(isContentOverlayVisible ? 1 : 0)
                        .allowsHitTesting(isContentOverlayVisible)
                    }
                    .ignoresSafeArea(.all, edges: [.bottom, .top])
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    vm.handleTap()
                }
        }
        
        if let selector = vm.controlRoomSelector {
            if showCRSelector {
                ControlRoomSelectorView(vm: selector, maxSize: vm.controlRoomMaxSize)
                    .id(ObjectIdentifier(selector)) // Required for SwiftUI to update
            }
        }
    }
    
    // MARK: - Covers
    
    /// Lets a tester schedule ad breaks before a video's first frame.
    /// Both before the first video and before switching to one from "Up next".
    @ViewBuilder
    private func adSetupGate(for video: Video?,
                             onPlay: @escaping () -> Void,
                             onCancel: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 10) {
                AdSchedulePanel(vm: vm, onClose: onPlay)
                
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.12), in: .capsule)
                    }
                    
                    Spacer(minLength: 0)
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(video?.name ?? "")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(vm.ads.scheduledAdBreaks.isEmpty
                             ? "No ads scheduled"
                             : "\(vm.ads.scheduledAdBreaks.count) break(s) scheduled")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Button(action: onPlay) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text(vm.ads.scheduledAdBreaks.isEmpty ? "Play without ads" : "Play")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(.yellow, in: .capsule)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .transition(.opacity)
    }
    
    @ViewBuilder
    private var loadingCover: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text(vm.session.isSwitchingContent ? "Switching…" : "Loading…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(vm.video?.name ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .transition(.opacity)
    }
    
    @ViewBuilder
    private func loadFailureCover(_ message: String) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.yellow)
                
                Text("Can't play \(vm.video?.name ?? "this video")")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                
                HStack(spacing: 12) {
                    Button {
                        vm.shouldDismiss = true
                    } label: {
                        Text("Back")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(.yellow, in: .capsule)
                    }
                    
                    if !vm.recommendations.isEmpty {
                        Button {
                            vm.isRecommendationsVisible = true
                        } label: {
                            Text("Pick another")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .background(.white.opacity(0.15), in: .capsule)
                        }
                    }
                }
            }
            .padding(24)
        }
        .transition(.opacity)
    }
    
    // MARK: - Test harness
    
    @ViewBuilder
    private var testHarnessPanels: some View {
        ZStack {
            if isAnyPanelVisible {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { dismissPanels() }
            }
            
            if vm.isRecommendationsVisible {
                VStack {
                    Spacer()
                    RecommendationsPanel(vm: vm, onClose: dismissPanels)
                        .padding(.bottom, 24)
                }
            }
            
            if vm.isAdSchedulerVisible {
                HStack {
                    Spacer()
                    AdSchedulePanel(vm: vm, onClose: dismissPanels)
                        .padding(.trailing, 20)
                        .padding(.vertical, 14)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isAnyPanelVisible)
    }
    
    // MARK: - Pieces
    
    @ViewBuilder
    private var arrowsLayout: some View {
        HStack {
            Button {
                vm.session.rotate(radians: .pi / 4)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 45, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
            .padding(.leading, 40)
            
            Spacer()
            
            Button {
                vm.session.rotate(radians: -.pi / 4)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 45, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
            .padding(.trailing, 40)
        }
    }
    
    @ViewBuilder
    private var subtitleOverlay: some View {
        VStack {
            if let cue = vm.session.subtitleCue, !cue.isEmpty {
                Text(cue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity)
                    .padding([.horizontal, .bottom], 16)
            }
        }
    }
    
    // MARK: - Actions
    
    private func dismissPanels() {
        vm.isRecommendationsVisible = false
        vm.isAdSchedulerVisible = false
    }
    
    private func startFromGate() async {
        vm.isAwaitingAdSetup = false
        await vm.startStream()
    }
}

#Preview(traits: .landscapeLeft) {
    StreamView(vm: StreamViewModel(video: Video.example))
}

struct ViewPreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    }
}
