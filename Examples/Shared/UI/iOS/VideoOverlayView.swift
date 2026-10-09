//
//  VideoOverlayView.swift
//  Shared
//
//  Created by Niko Inas on 25.02.24.
//

import SwiftUI
import YBVRAppleSDK

/**
 The player's controls, anchored to the screen's edges and always on screen: the way back and
 the title at the top; the playback controls at the bottom, with the subtitles directly above
 them and `accessories` - the action bar, the camera map - above those.
 */
struct VideoOverlayView<Model: PlayerControlsModel, Accessories: View>: View {
    
    let vm: Model
    @ViewBuilder let accessories: () -> Accessories
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack(spacing: 12) {
                PlayerControlButton(icon: "arrow.backward") {
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
            }
            .padding([.top, .horizontal], 16)
            
            Spacer(minLength: 0)
            
            VStack(spacing: 6) {
                accessories()
                PlayerSubtitles(cue: vm.subtitleCue)
                VideoPlayerControlsView(vm: vm)
            }
            .padding([.horizontal, .bottom], 16)
            .layoutPriority(1)
        }
    }
}

extension VideoOverlayView where Accessories == EmptyView {
    init(vm: Model) {
        self.init(vm: vm, accessories: { EmptyView() })
    }
}
