//
//  RecommendationsPanel.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

struct RecommendationsPanel: View {
    @Environment(PlayerCoordinator.self) private var coordinator
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var videoAwaitingAdSetup: Video?
    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 16)]
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)
            
            HarnessDivider()
            
            content
        }
        .frame(width: 940, height: 560)
        .background(Color.black)
        .sheet(item: $videoAwaitingAdSetup) { video in
            AdSetupSheet(
                harness: coordinator.ads,
                video: video,
                onPlay: {
                    videoAwaitingAdSetup = nil
                    Task {
                        if await coordinator.switchTo(video: video) {
                            coordinator.ads.endStaging()
                        } else {
                            coordinator.ads.cancelStaging()
                        }
                    }
                },
                onCancel: {
                    videoAwaitingAdSetup = nil
                    coordinator.ads.cancelStaging()
                }
            )
        }
        .onDisappear {
            coordinator.showRecommendations = false
        }
    }
    
    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.play.fill")
                .foregroundStyle(.yellow)
            
            Text("Up next")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            
            if coordinator.session.isSwitchingContent {
                ProgressView()
                    .controlSize(.small)
                Text("switching…")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer(minLength: 0)
            
            Button {
                dismissWindow(id: SceneID.recommendationsPanel)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        let videos = coordinator.switchableVideos
        
        if videos.isEmpty {
            VStack(spacing: 6) {
                Text("Nothing to switch to")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("The other videos in the list need a different scene than the one open.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 420, maxHeight: .infinity)
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                if let failure = coordinator.switchFailure {
                    Text(failure)
                        .font(.system(size: 12))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.yellow, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 14)
                }
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(videos) { video in
                        card(for: video)
                    }
                }
            }
            .padding(20)
        }
    }
    
    @ViewBuilder
    private func card(for video: Video) -> some View {
        Button {
            coordinator.ads.beginStagingForNextContent()
            videoAwaitingAdSetup = video
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.12))
                    Image(systemName: "play.circle")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(height: 110)
                
                Text(video.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(video.isLive ? "Live" : "VOD")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .disabled(coordinator.session.isSwitchingContent)
        .opacity(coordinator.session.isSwitchingContent ? 0.5 : 1)
    }
}

#Preview {
    RecommendationsPanel()
        .environment(PlayerCoordinator(environment: AppEnvironment()))
}
