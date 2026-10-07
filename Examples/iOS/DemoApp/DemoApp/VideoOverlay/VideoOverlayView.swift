//
//  VideoOverlayView.swift
//  DemoApp
//
//  Created by Niko Inas on 25.02.24.
//

import SwiftUI
import YBVRAppleSDK

/// Header + playback controls shared by every player. `cameraOverlay` carries whatever extra,
/// pipeline-specific UI sits right above the transport bar - the camera map and its toolbar for a
/// YBVR stream, nothing for a direct HLS stream.
struct VideoOverlayView<Model: PlayerControlsModel, CameraOverlay: View>: View {
    
    let vm: Model
    @ViewBuilder let cameraOverlay: () -> CameraOverlay
    
    private let height = UIScreen.main.bounds.height
    private let width = UIScreen.main.bounds.width
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack(spacing: 12) {
                PlayerControlButton(icon: "arrow.backward", onInteract: vm.startOverlayTimer) {
                    vm.requestDismiss()
                }
                .playerGlass(in: Circle())
                
                VStack(alignment: .leading) {
                    Text(vm.headerTitle)
                        .font(.subtitle)
                    if !vm.headerSubtitle.isEmpty {
                        Text(vm.headerSubtitle)
                            .font(.regular)
                    }
                }
                .multilineTextAlignment(.leading)
                .foregroundStyle(.white)
                
                Spacer(minLength: 0)
                
                if vm.showsTestHarness {
                    testHarnessToolbar
                }
            }
            .padding([.top, .horizontal], 16)
            
            Spacer(minLength: 0)
            
            VStack(spacing: 6) {
                cameraOverlay()
                VideoPlayerControlsView(vm: vm)
            }
            .padding([.horizontal, .bottom], 16)
            // First call on the room below the header, ahead of the spacer: whatever in
            // `cameraOverlay` can fill it - an open camera map - gets it all rather than half.
            .layoutPriority(1)
        }
    }
    
    @ViewBuilder
    var testHarnessToolbar: some View {
        HStack(spacing: 10) {
            toolbarButton(icon: "rectangle.stack.badge.play.fill",
                          title: "Up next",
                          isActive: vm.isRecommendationsVisible) {
                vm.isRecommendationsVisible.toggle()
                if vm.isRecommendationsVisible { vm.isAdSchedulerVisible = false }
            }
        }
    }
    
    @ViewBuilder
    func toolbarButton(icon: String,
                       title: String,
                       isActive: Bool,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isActive ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? Color.yellow : Color.black.opacity(0.5), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(isActive ? 0 : 0.3), lineWidth: 1))
        }
    }
}

extension VideoOverlayView where CameraOverlay == EmptyView {
    init(vm: Model) {
        self.init(vm: vm, cameraOverlay: { EmptyView() })
    }
}

#Preview(traits: .landscapeLeft) {
    VideoOverlayView(vm: StreamViewModel(video: Video.example)) {
        EmptyView()
    }
    .background(Color.gray)
}
