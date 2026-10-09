//
//  VideoLibraryView.swift
//  Shared
//
//  Shared by the iOS and visionOS apps.
//

import SwiftUI
import YBVRAppleSDK

/// The video library: a header, and a fixed two-by-two grid of the first four videos in the list.
struct VideoLibraryView: View {
    let catalog: VideoCatalog
    let onSelect: (Video) -> Void
    
    static let itemCount = 4
    
    var body: some View {
        VStack(spacing: 24) {
            header
            
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                let videos = Array(catalog.videos.prefix(Self.itemCount))
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { column in
                            let index = row * 2 + column
                            if videos.indices.contains(index) {
                                card(for: videos[index])
                            } else {
                                Color.clear
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var header: some View {
        VStack(spacing: 6) {
            Text("Video Library")
                .font(.system(size: 28, weight: .bold))
            Text("Select an experience to watch")
                .font(.system(size: 15, weight: .medium))
                .tracking(1)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
    }
    
    private func card(for video: Video) -> some View {
        Button {
            onSelect(video)
        } label: {
            VideoCard(title: video.name)
        }
        .buttonStyle(VideoCardButtonStyle())
    }
}

// MARK: - Card

/// One video on offer: its title.
struct VideoCard: View {
    let title: String
    
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        Text(title)
            .font(.system(size: 17))
            .foregroundStyle(.white)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 0, idealHeight: 150, maxHeight: 150,
                   alignment: .topLeading)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

struct VideoCardButtonStyle: ButtonStyle {
    private static let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.06 : 0.1), in: Self.shape)
            .contentShape(.hoverEffect, Self.shape)
            .hoverEffect(.highlight)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
