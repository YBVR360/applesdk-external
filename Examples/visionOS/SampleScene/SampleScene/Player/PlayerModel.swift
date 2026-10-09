//
//  PlayerModel.swift
//  SampleScene
//

import SwiftUI
import CompositorServices
import YBVRAppleSDK

/**
 Plays one video at a time in the immersive space: a `PlaybackSession` around a
 `YBVRPlayerManager` that renders through Compositor Services, its cameras, and the state of the
 controls window.
 
 1. `begin(video:)` from the list, before opening the immersive space.
 2. `prepare(layerRenderer:)` and `start()` from the space, once it has a renderer.
 3. `end()` once the viewer has left, or the system has closed the space - `isSpaceClosedBySystem`.
 */
@MainActor
@Observable
final class PlayerModel {
    
    /// The player and everything it publishes.
    let session = PlaybackSession()
    /// The notice anchored above the controls: camera changes, an unstable connection.
    let notice = PlayerNotice()
    
    private let players: PlayerFactory
    
    /// `true` from the moment the space builds a player until the video is over.
    private(set) var isPresenting = false
    /// `true` once the video is over and the space should close - it ended, failed, or the
    /// viewer asked to leave.
    private(set) var isFinished = false
    /// `true` once the system has closed the space while the video was still on screen.
    private(set) var isSpaceClosedBySystem = false
    /// Why the video could not be played. Shown by the list once the space has closed.
    var failure: PlayerNotifications.Modal?
    
    /// Whether the controls window is open. They never hide by themselves: if the viewer closes
    /// the window, a pinch in the space asks for it back through `controlsRequest`.
    var isControlsWindowOpen = false
    /// Bumped to ask the immersive scene to open the controls window.
    private(set) var controlsRequest = 0
    
    var isCameraMapOpen = false
    /// `true` while the control room's camera is the one playing.
    private(set) var isInControlRoom = false {
        didSet { updateMiniScreens() }
    }
    /// While in the control room, `true` to watch the feed playing alone, without the mini
    /// screens around it.
    var isFullScreen = false {
        didSet { updateMiniScreens() }
    }
    
    /// Whether the control room's mini screens are on screen around the feed playing.
    var isMultiviewVisible: Bool { isInControlRoom && !isFullScreen }
    
    @ObservationIgnored private var areMiniScreensShown = false
    
    private func updateMiniScreens() {
        guard areMiniScreensShown != isMultiviewVisible else { return }
        areMiniScreensShown = isMultiviewVisible
        session.showControlRoomMiniScreens(isMultiviewVisible)
    }
    
    var isSessionOnScreen: Bool { isPresenting && !isFinished }
    
    init(players: PlayerFactory) {
        self.players = players
        
        session.onEnded = { [weak self] in
            self?.isFinished = true
        }
        session.onFailure = { [weak self] _ in
            self?.fail(with: PlayerNotifications.somethingWentWrong)
        }
        session.onCameraChangeBegan = { [weak self] in
            self?.notice.cameraChangeBegan()
        }
        session.onCameraChangeEnded = { [weak self] in
            self?.notice.cameraChangeEnded()
        }
        session.onSpaceClosed = { [weak self] in
            self?.isSpaceClosedBySystem = true
        }
    }
    
    /// - Parameter signaling: The video's signaling when it was already fetched, so it is not
    ///   fetched again.
    func begin(video: Video, signaling: SignalingInterface? = nil) {
        session.begin(video: video, signaling: signaling)
        isFinished = false
        isSpaceClosedBySystem = false
        failure = nil
        isCameraMapOpen = false
        isInControlRoom = false
        isFullScreen = false
    }
    
    /// Builds a player that renders into the immersive space's compositor layer.
    func prepare(layerRenderer: LayerRenderer) {
        isPresenting = true
        let surface = VisionSurfaceContext(layerRenderer: layerRenderer)
        session.attach(player: players.makePlayer(surfaceContext: surface))
    }
    
    /// Fetches the video's signaling, opens the stream, and starts.
    @discardableResult
    func start() async -> Bool {
        guard await session.start() else {
            // A start that fails because the session already ended - the connection dropped -
            // keeps the reason it ended for.
            fail(with: PlayerNotifications.somethingWentWrong)
            return false
        }
        
        if let firstAudio = session.selectableAudioLanguages.first {
            await session.setAudioLanguage(firstAudio)
        }
        adoptCurrentCamera()
        return true
    }
    
    /// Ends the video with a blocking notification, which the list shows once the space has closed.
    func fail(with modal: PlayerNotifications.Modal) {
        guard isSessionOnScreen else { return }
        failure = modal
        isFinished = true
    }
    
    func end() {
        notice.reset()
        session.end()
        isPresenting = false
        isInControlRoom = false
        isFullScreen = false
    }
}

// MARK: - Cameras

extension PlayerModel {
    
    /// More than one camera to choose between.
    var hasCameraMap: Bool { session.offersCameraMap }
    
    /// Plays the camera a camera map pin stands for.
    func select(viewPoint: ViewPoint) async {
        await session.select(viewPoint: viewPoint)
        adoptCurrentCamera()
    }
    
    /// Handles pinches anywhere in the immersive space: one that lands on a control room mini
    /// screen plays that feed, and any pinch brings back the controls window if it was closed.
    func handlePinches(_ events: SpatialEventCollection) {
        for event in events where event.kind == .indirectPinch && event.phase == .ended {
            if !isControlsWindowOpen {
                controlsRequest += 1
            }
            
            // The tracking area identifier is the mini screen's index + 1, when hover effects
            // are on; otherwise the ray is tested against the mini screens.
            let trackId = event.trackingAreaIdentifier.rawValue
            if trackId > 0 {
                selectControlRoomFeed(atIndex: Int(trackId) - 1)
            } else if let ray = event.selectionRay,
                      let index = session.player?.hitTestCRMiniScreen(
                        rayDirection: simd_float3(Float(ray.direction.x),
                                                  Float(ray.direction.y),
                                                  Float(ray.direction.z))) {
                selectControlRoomFeed(atIndex: index)
            }
        }
    }
    
    private func selectControlRoomFeed(atIndex index: Int) {
        guard isMultiviewVisible,
              let feeds = session.controlRoomSelector?.controlRoomCameras,
              feeds.indices.contains(index) else { return }
        
        session.selectControlRoomCamera(atIndex: index)
    }
    
    private func adoptCurrentCamera() {
        guard let camera = session.camera else { return }
        
        isFullScreen = false
        isInControlRoom = camera.isControlRoom
    }
}

// MARK: - PlayerControlsModel

extension PlayerModel: PlayerControlsModel {
    
    var headerTitle: String { session.video?.name ?? "" }
    var headerSubtitle: String { session.camera?.name ?? "" }
    
    var isLive: Bool { session.isLive }
    var canSeek: Bool { session.canSeek }
    var isPlaying: Bool { session.isPlaying }
    var isAtLiveEdge: Bool { session.isAtLiveEdge }
    var isScrubbing: Bool { session.isScrubbing }
    var position: Double { session.position }
    var duration: Double { session.duration }
    
    func togglePlayPause() { session.togglePlayPause() }
    func jump(by seconds: Double) { session.jump(by: seconds) }
    func goToLive() { session.goToLive() }
    func beginScrub() { session.beginScrub() }
    func endScrub() { session.endScrub() }
    func commitScrub(to seconds: Double) { session.commitScrub(to: seconds) }
    
    func requestDismiss() { isFinished = true }
    
    var availableAudioLanguages: [String] { session.availableAudioLanguages }
    var selectableAudioLanguages: [String] { session.selectableAudioLanguages }
    var currentAudioLanguage: String { session.audioLanguage }
    
    var availableSubtitlesLanguages: [String] { session.availableSubtitlesLanguages }
    var selectableSubtitlesLanguages: [String] { session.selectableSubtitlesLanguages }
    var currentSubtitlesLanguage: String { session.subtitlesLanguage }
    
    func setAudioLanguage(_ language: String) async {
        await session.setAudioLanguage(language)
    }
    
    func setSubtitlesLanguage(_ language: String) async {
        await session.setSubtitlesLanguage(language)
    }
    
    var subtitleCue: String? { session.subtitleCue }
    
    var volume: Double {
        get { session.volume }
        set { session.volume = newValue }
    }
}
