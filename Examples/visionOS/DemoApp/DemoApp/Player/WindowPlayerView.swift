//
//  WindowPlayerView.swift
//  DemoApp
//
//  Created by Manuel Tirado on 28.08.26.
//

import SwiftUI
import YBVRAppleSDK

/// The session rendered into a plain window, with the control room's mini screens as ornaments
/// beside it. The alternative to the immersive scenes; `PlayerCoordinator` moves between them.
struct WindowPlayerView: View {
    @Environment(PlayerCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var videoHeight: CGFloat = 0
    
    private var session: PlaybackSession { coordinator.session }
    
    /// `true` while this view is the one rendering the session.
    private var isCurrentSurface: Bool {
        coordinator.surface == .window
    }
    
    private var isControlRoomVisible: Bool {
        videoHeight > 0 && controlRoom != nil && !coordinator.isSwitchingSurface
    }
    
    /// The mini screens, split into the two ornaments they are drawn in. Odd counts put the
    /// extra screen on the leading side.
    private var controlRoom: (selector: ControlRoomSelectorViewModel,
                              leading: Range<Int>,
                              trailing: Range<Int>)? {
        guard coordinator.showControlRoomSelector,
              let selector = session.controlRoomSelector
                else { return nil }
        
        let count = selector.controlRoomCameras.count
        guard count > 0 else { return nil }
        
        let split = (count + 1) / 2
        return (selector, 0..<split, split..<count)
    }
    
    var body: some View {
        content
            .overlay {
                restoringOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: 46))
            .aspectRatio(Ratios.videoRatio, contentMode: .fit)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                videoHeight = $0
            }
            .overlay(alignment: .bottom) { subtitleOverlay }
            .contentShape(Rectangle())
            .onTapGesture {
                coordinator.overlay.show()
            }
            .ornament(
                visibility: coordinator.overlay.isVisible ? .visible : .hidden,
                attachmentAnchor: .scene(.bottom),
                contentAlignment: .top
            ) {
                PlayerControlsWindow()
            }
            .ornament(
                visibility: isControlRoomVisible ? .visible : .hidden,
                attachmentAnchor: .scene(.leading),
                contentAlignment: .trailing
            ) {
                miniScreens(controlRoom?.leading, invertedOrder: true)
            }
            .ornament(
                visibility: isControlRoomVisible ? .visible : .hidden,
                attachmentAnchor: .scene(.trailing),
                contentAlignment: .leading
            ) {
                miniScreens(controlRoom?.trailing, invertedOrder: false)
            }
            .task {
                await startPlayback()
            }
            .onAppear {
                dismissWindow(id: SceneID.startingScene)
                dismissWindow(id: SceneID.playerControls)
                coordinator.overlay.show()
            }
            .onDisappear {
                guard isCurrentSurface, !coordinator.isSwitchingSurface else { return }
                coordinator.end()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .background, isCurrentSurface else { return }
                session.pause()
            }
            .onChange(of: coordinator.isFinished) { _, finished in
                guard finished else { return }
                
                coordinator.end()
                openWindow(id: SceneID.startingScene)
            }
            .onReceive(NotificationCenter.default.publisher(for: .videoIsReady)) { _ in
                coordinator.overlay.show()
            }
    }
    
    // MARK: - Pieces
    
    @ViewBuilder
    private var content: some View {
        if let player = session.player {
            GeometryVideoView(sc: player.getSurfaceController())
                .id(session.generation) // The surface controller belongs to one manager.
        } else {
            Color.black
        }
    }
    
    @ViewBuilder
    private func miniScreens(_ indices: Range<Int>?, invertedOrder: Bool) -> some View {
        if let controlRoom, let indices {
            ControlRoomMiniGrid(selector: controlRoom.selector,
                                indices: indices,
                                height: videoHeight,
                                invertedOrder: invertedOrder)
        }
    }
    
    @ViewBuilder
    private var restoringOverlay: some View {
        if coordinator.isSwitchingSurface {
            ZStack {
                Color.black
                ProgressView()
            }
            .transition(.opacity)
        }
    }
    
    /// The window player's Metal surface does not draw cues into the video, so the app has to
    /// put them on screen itself.
    @ViewBuilder
    private var subtitleOverlay: some View {
        if session.presentsSubtitles, let cue = session.subtitleCue, !cue.isEmpty {
            Text(cue)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 24)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.15), value: cue)
        }
    }
    
    private func startPlayback() async {
        coordinator.prepareForWindow()
        await coordinator.startPlayback()
    }
}

// MARK: - Control room mini screens

private struct ControlRoomMiniGrid: View {
    let selector: ControlRoomSelectorViewModel
    let indices: Range<Int>
    let height: CGFloat
    let invertedOrder: Bool
    
    private static let maxRows = 4
    private static let spacing: CGFloat = 8
    private static let horizontalPadding: CGFloat = 12
    
    private var columns: Int {
        max(1, (indices.count + Self.maxRows - 1) / Self.maxRows)
    }
    
    private var rows: Int {
        max(1, min(indices.count, Self.maxRows))
    }
    
    private var cellHeight: CGFloat {
        let laidOutRows = CGFloat(Self.maxRows)
        let available = height - Self.spacing * (laidOutRows - 1)
        return max(0, available / laidOutRows)
    }
    
    private var cellWidth: CGFloat { cellHeight * Ratios.smallVideoRatio }
    
    var body: some View {
        Grid(horizontalSpacing: Self.spacing, verticalSpacing: Self.spacing) {
            ForEach(0..<rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { position in
                        let column = invertedOrder ? columns - 1 - position : position
                        cell(atOffset: column * rows + row)
                    }
                }
            }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .frame(height: height)
        .id(ObjectIdentifier(selector))
    }
    
    @ViewBuilder
    private func cell(atOffset offset: Int) -> some View {
        if offset < indices.count {
            let index = indices.lowerBound + offset
            
            ControlRoomView(vm: selector,
                            camera: selector.controlRoomCameras[index],
                            index: index)
            .frame(width: cellWidth, height: cellHeight)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .onAppear { selector.subscribeToCamera(at: index) }
            .onDisappear { selector.unsubscribeFromCamera(at: index) }
        } else {
            Color.clear
                .frame(width: cellWidth, height: cellHeight)
        }
    }
}

#Preview {
    WindowPlayerView()
        .environment(PlayerCoordinator(environment: AppEnvironment()))
}
