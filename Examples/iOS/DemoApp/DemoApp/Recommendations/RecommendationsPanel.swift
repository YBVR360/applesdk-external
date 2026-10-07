//
//  RecommendationsPanel.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

struct RecommendationsPanel: View {
    @State var vm: StreamViewModel
    var onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            
            if let failure = vm.switchFailure {
                Text(failure)
                    .font(.system(size: 12))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.yellow, in: RoundedRectangle(cornerRadius: 8))
            }
            
            if vm.recommendations.isEmpty {
                Text("No other videos in the list.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.recommendations) { video in
                            card(for: video)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 620)
        .background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15), lineWidth: 1))
        .foregroundStyle(.white)
    }
    
    @ViewBuilder
    var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack.badge.play.fill")
            Text("Up next")
                .font(.system(size: 15, weight: .semibold))
            
            if vm.session.isSwitchingContent {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text("switching…")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer(minLength: 0)
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(6)
                    .contentShape(Rectangle())
            }
        }
    }
    
    @ViewBuilder
    func card(for video: Video) -> some View {
        let isCurrent = video == vm.video
        
        Button {
            vm.prepareSwitch(to: video)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.12))
                    Image(systemName: isCurrent ? "play.circle.fill" : "play.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(isCurrent ? .yellow : .white.opacity(0.8))
                }
                .frame(width: 150, height: 84)
                
                Text(video.name)
                    .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 150, alignment: .leading)
                
                Text(isCurrent ? "Playing" : (video.isLive ? "Live" : "VOD"))
                    .font(.system(size: 10))
                    .foregroundStyle(isCurrent ? .yellow : .white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .disabled(isCurrent || vm.session.isSwitchingContent)
        .opacity(vm.session.isSwitchingContent && !isCurrent ? 0.5 : 1)
    }
}

#Preview(traits: .landscapeLeft) {
    RecommendationsPanel(vm: .init(video: .example)) {
        
    }
}
