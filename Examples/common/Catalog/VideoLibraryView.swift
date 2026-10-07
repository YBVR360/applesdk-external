//
//  VideoLibraryView.swift
//  DemoApp
//
//  Shared by the iOS and visionOS demo apps.
//

import SwiftUI
import YBVRAppleSDK

/**
 The list of videos on offer: a header, and a grid of `VideoCard`s.
 
 The same on both platforms but for how it is framed - a glass panel of its own on visionOS, the
 screen's scroll view on iOS - and how many columns it has, which is the host's call: visionOS
 always has room for two, a phone only when turned sideways.
 */
struct VideoLibraryView: View {
    let catalog: VideoCatalog
    var columns: Int = 2
    let onSelect: (Video) -> Void
    
    private static let spacing: CGFloat = 16
    
    var body: some View {
        VStack(spacing: 24) {
            header
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing,
                                                         alignment: .top),
                                     count: max(columns, 1)),
                      spacing: Self.spacing) {
                ForEach(catalog.videos) { video in
                    Button {
                        onSelect(video)
                    } label: {
                        VideoCard(title: video.name,
                                  isLive: video.isLive,
                                  experience: catalog.experience(of: video))
                    }
                    .buttonStyle(VideoCardButtonStyle())
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
}

// MARK: - Card

/// One video on offer: whether it is live, its title, and how it is watched.
struct VideoCard: View {
    let title: String
    let isLive: Bool
    let experience: VideoCatalog.Experience?
    
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLive {
                LiveNowBadge()
            }
            
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
            
            if let experience {
                ExperienceBadge(experience: experience)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// How a card reacts: lighter while looked at or hovered, darker and a little smaller while
/// pressed. The card itself draws no background, so the three share one shape.
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

// MARK: - Badges

/// The white "LIVE NOW" tag at the top of a live video's card.
struct LiveNowBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
            Text("LIVE NOW")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// The tag at the foot of a card saying how the video is watched.
struct ExperienceBadge: View {
    let experience: VideoCatalog.Experience
    
    private var title: String {
        switch experience {
        case .singleView: "Single-View"
        case .immersive: "Immersive"
        }
    }
    
    private var icon: String {
        switch experience {
        case .singleView: "display"
        case .immersive: "visionpro"
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.black.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Previews

#Preview("Cards") {
    let card = { (title: String, isLive: Bool, experience: VideoCatalog.Experience) in
        Button {} label: {
            VideoCard(title: title, isLive: isLive, experience: experience)
        }
        .buttonStyle(VideoCardButtonStyle())
    }
    
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            card("Midwest Classic Championship: Nebraska vs. Minnesota Ultimate Showdown",
                 false, .singleView)
            card("South Dakota vs. Iowa: Epic Showdown Highlights with the best plays",
                 true, .immersive)
        }
        HStack(spacing: 16) {
            card("Midwest Classic Championship", false, .singleView)
            card("South Dakota vs. Iowa", true, .immersive)
                .disabled(true)
        }
    }
    .padding()
    .background(Color(white: 0.28))
}
