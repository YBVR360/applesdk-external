//
//  PlayerViewModel.swift
//  SampleScene
//

import SwiftUI
import YBVRAppleSDK

/**
 Plays one video: a `PlaybackSession` around a `YBVRPlayerManager`, its cameras, and the state of
 the controls on top.
 
 iOS renders through the manager's own surface controller, so one player lasts for as long as
 the screen is up.
 */
@MainActor
@Observable
final class PlayerViewModel {
    
    /// The player and everything it publishes.
    let session = PlaybackSession()
    /// The notice anchored above the controls: camera changes, an unstable connection.
    let notice = PlayerNotice()
    
    /// Set when the screen should close - the video ended, or the viewer asked to go back.
    var shouldDismiss = false
    
    var isCameraMapOpen = false
    /// `true` while the control room's camera is the one playing.
    private(set) var isInControlRoom = false
    /// While in the control room, `true` to watch the feed playing alone, without the grid of
    /// feeds beside it.
    var isFullScreen = false
    
    /// Whether the control room panel is on screen beside the feed playing.
    var isMultiviewVisible: Bool { isInControlRoom }
    
    /// How much of the screen the control room grid is allowed to take.
    private let controlRoomScreenPercent = CGSize(width: 0.20, height: 0.15)
    
    /// - Parameter signaling: The video's signaling when it was already fetched, so it is not
    ///   fetched again.
    init(video: Video, signaling: SignalingInterface? = nil, players: PlayerFactory) {
        session.begin(video: video, signaling: signaling)
        session.attach(player: players.makePlayer())
        session.onEnded = { [weak self] in self?.shouldDismiss = true }
        session.onCameraChangeBegan = { [weak self] in self?.notice.cameraChangeBegan() }
        session.onCameraChangeEnded = { [weak self] in self?.notice.cameraChangeEnded() }
    }
    
    var player: YBVRPlayerManager? { session.player }
    var presentation: PlayerPresentation? { session.presentation }
    
    /// Set when the video could not be played. The player closes and the list shows it.
    var failure: String? { session.failure }
    
    /// Fetches the video's signaling, opens the stream, and starts on its first audio track.
    func start() async {
        guard await session.start() else { return }
        
        if let firstAudio = session.selectableAudioLanguages.first {
            await session.setAudioLanguage(firstAudio)
        }
        adoptCurrentCamera()
    }
    
    func stop() {
        notice.reset()
        session.end()
    }
}

// MARK: - Cameras

extension PlayerViewModel {
    
    /// More than one camera to choose between.
    var hasCameraMap: Bool { session.offersCameraMap }
    
    var controlRoomSelector: ControlRoomSelectorViewModel? { session.controlRoomSelector }
    
    /// 180° and 360° content, which can be looked around and so recentred.
    var isShowingImmersiveContent: Bool {
        guard let camera = session.camera else {
            return session.video?.signalingVersion == .nsEquirectangularMono
        }
        return !camera.isFlatCamera
    }
    
    /// How big the control room grid may draw, in points.
    var controlRoomMaxSize: CGSize {
        let screen = UIScreen.main.bounds.size
        let (long, short) = screen.width >= screen.height
        ? (screen.width, screen.height)
        : (screen.height, screen.width)
        
        return CGSize(width: controlRoomScreenPercent.width * long,
                      height: controlRoomScreenPercent.height * short)
    }
    
    /// Plays the camera a camera map pin stands for.
    func select(viewPoint: ViewPoint) async {
        await session.select(viewPoint: viewPoint)
        adoptCurrentCamera()
    }
    
    func recenter() {
        session.recenter()
    }
    
    private func adoptCurrentCamera() {
        guard let camera = session.camera else { return }
        
        isInControlRoom = camera.isControlRoom
        isFullScreen = false
    }
}

// MARK: - PlayerControlsModel

extension PlayerViewModel: PlayerControlsModel {
    
    var headerTitle: String { session.video?.name ?? "" }
    var headerSubtitle: String { presentation?.headerSubtitle ?? "" }
    
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
    
    func requestDismiss() { shouldDismiss = true }
    
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
