//
//  PlayerControlsWindow.swift
//  SampleScene
//

import SwiftUI
import YBVRAppleSDK

/**
 The controls, as a window of their own in front of the immersive video: the playback
 controls, with the subtitles directly above them, the action bar and any notice above those,
 and the camera map below. Open for as long as the video plays.
 */
struct PlayerControlsWindow: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        PlayerTransportControls(vm: player)
            .ornament(attachmentAnchor: .parent(.top), contentAlignment: .bottom) {
                VStack(spacing: 12) {
                    PlayerNoticeBanner(notice: player.notice)
                    ActionBar(actions: actions)
                    PlayerSubtitles(cue: player.subtitleCue)
                }
                .padding(8)
                .animation(.easeInOut(duration: 0.2), value: player.notice.message)
            }
            .ornament(
                visibility: player.isCameraMapOpen && player.hasCameraMap ? .visible : .hidden,
                attachmentAnchor: .parent(.bottom),
                contentAlignment: .top
            ) {
                CameraMapView()
                    .cameraMap(session: player.session) { viewPoint in
                        await player.select(viewPoint: viewPoint)
                    }
                    .padding(12)
            }
            .onAppear {
                guard player.isSessionOnScreen else {
                    dismissWindow(id: SceneID.playerControls)
                    return
                }
                player.isControlsWindowOpen = true
            }
            .onDisappear {
                player.isControlsWindowOpen = false
            }
    }
    
    private var actions: [ActionBar.Action] {
        var actions: [ActionBar.Action] = []
        
        if player.hasCameraMap {
            actions.append(.init(title: "Camera Map", icon: "mappin.and.ellipse",
                                 isActive: player.isCameraMapOpen) {
                player.isCameraMapOpen.toggle()
            })
        }
        
        return actions
    }
}
