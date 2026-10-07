//
//  StreamViewModel.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

@MainActor
@Observable
final class StreamViewModel {
    
    /// The player and everything it publishes.
    let session = PlaybackSession()
    /// Ad breaks scheduled by hand, for exercising ad insertion.
    let ads = AdHarness()
    /// The controls, and the idle timer that takes them away again.
    let overlay = OverlayVisibility(autoHideInterval: 5)
    
    // MARK: - Screen state
    
    /// `true` while the ad-setup gate is up, before playback has been asked for.
    var isAwaitingAdSetup = true
    /// The "up next" video whose ad breaks are being set up, before switching to it.
    private(set) var pendingSwitch: Video?
    /// `true` while the control room's camera selector is the thing on screen.
    var isCameraSelectorAppeared = false
    var isFullScreen = false
    var isRecommendationsVisible = false
    var isAdSchedulerVisible = false
    /// Why the last content switch was refused, or `nil`. Shown by the recommendations panel.
    private(set) var switchFailure: String?
    /// Set when the screen should close - the video ended, or the viewer asked to go back.
    var shouldDismiss = false
    
    // MARK: - Content
    
    /// Other videos from the list, offered as "up next". Switching to one reuses this player,
    /// so APMP videos, which play through `DirectPlayer`, are left out.
    private(set) var recommendations: [Video] = []
    private let allVideos: [Video]
    /// How much of the screen the control room selector is allowed to take.
    let controlRoomScreenPercent: CGSize
    
    // MARK: - Init
    
    init(video: Video,
         players: PlayerFactory? = nil,
         signaling: SignalingInterface? = nil,
         recommendations: [Video] = [],
         controlRoomScreenPercent: CGSize = CGSize(width: 0.20, height: 0.15)) {
        
        self.allVideos = recommendations.filter { !PlaybackRoute.isApmp($0) }
        self.recommendations = allVideos.filter { $0 != video }
        self.controlRoomScreenPercent = controlRoomScreenPercent
        
        session.begin(video: video, signaling: signaling)
        
        // iOS renders through the manager's own surface controller and never swaps surfaces,
        // so the session gets its one player here and keeps it for the whole screen.
        let player = (players ?? PlayerFactory()).makePlayer(surfaceContext: nil)
        session.attach(player: player)
        ads.attach(to: player)
        
        wireUp()
    }
    
    private func wireUp() {
        // Controls stay up while playback is paused.
        overlay.canAutoHide = { [weak self] in self?.session.isPlaying ?? false }
        
        // An ad owns the screen.
        ads.onPlaybackChanged = { [weak self] playback in
            guard let self else { return }
            self.overlay.setPinned(playback != nil, reason: "ad")
            if playback != nil { self.overlay.hide() }
        }
        
        session.onEnded = { [weak self] in
            self?.shouldDismiss = true
        }
    }
}

// MARK: - Playback

extension StreamViewModel {
    
    var player: YBVRPlayerManager? { session.player }
    
    var video: Video? { session.video }
    
    var presentation: PlayerPresentation? { session.presentation }
    
    var isShowingImmersiveContent: Bool {
        guard player != nil else { return false }
        
        guard let camera = session.camera else {
            return video?.signalingVersion == .nsEquirectangularMono
        }
        return !camera.isFlatCamera
    }
    
    var controlRoomSelector: ControlRoomSelectorViewModel? { session.controlRoomSelector }
    
    /// How big the control room selector may draw, in points.
    var controlRoomMaxSize: CGSize {
        let screen = UIScreen.main.bounds.size
        let (long, short) = screen.width >= screen.height
        ? (screen.width, screen.height)
        : (screen.height, screen.width)
        
        return CGSize(width: controlRoomScreenPercent.width * long,
                      height: controlRoomScreenPercent.height * short)
    }
    
    func startStream() async {
        guard await session.start() else { return }
        adoptCurrentContent()
        overlay.show()
    }
    
    func prepareSwitch(to video: Video) {
        ads.beginStagingForNextContent()
        pendingSwitch = video
        isRecommendationsVisible = false
    }
    
    /// Switches to the video the gate was opened for, taking the schedule set up for it.
    func confirmSwitch() async {
        guard let video = pendingSwitch else { return }
        pendingSwitch = nil
        
        if await switchTo(video: video) {
            ads.endStaging()
        } else {
            ads.cancelStaging()
        }
    }
    
    /// Closes the gate and puts the current video's schedule back.
    func cancelSwitch() {
        pendingSwitch = nil
        ads.cancelStaging()
    }
    
    /// Switches to another video without tearing the player down, so the surface and the
    /// underlying `AVPlayer` survive and the whole player UI stays mounted.
    private func switchTo(video newVideo: Video) async -> Bool {
        switchFailure = nil
        
        let signaling: SignalingInterface?
        do {
            signaling = try await PlaybackRoute.signalingForSwitch(to: newVideo)
        } catch {
            // The old content keeps playing; the panel comes back up to show why.
            switchFailure = error.localizedDescription
            isRecommendationsVisible = true
            return false
        }
        
        guard await session.switchContent(to: newVideo, signaling: signaling) else { return false }
        
        ads.reapplyForNewContent()
        adoptCurrentContent()
        isRecommendationsVisible = false
        overlay.show()
        return true
    }
    
    private func adoptCurrentContent() {
        recommendations = allVideos.filter { $0 != session.video }
    }
    
    func stop() {
        pendingSwitch = nil
        overlay.reset()
        ads.detach()
        session.end()
    }
    
    // MARK: Cameras
    
    func didSelect(camera: YBVRCamera) async {
        overlay.hide()
        await session.select(camera: camera)
    }
    
    func didSelect(viewPoint: ViewPoint) async {
        await session.select(viewPoint: viewPoint)
    }
}

// MARK: - PlayerControlsModel

extension StreamViewModel: PlayerControlsModel {
    
    var headerTitle: String { session.video?.name ?? "" }
    var headerSubtitle: String { session.presentation?.headerSubtitle ?? "" }
    
    /// A tap anywhere on the video shows or hides the controls.
    func handleTap() {
        guard !ads.isPlayingAd else { return }
        overlay.toggle()
    }
    
    var isLive: Bool { session.isLive }
    var canSeek: Bool { session.canSeek }
    var isPlaying: Bool { session.isPlaying }
    var isAtLiveEdge: Bool { session.isAtLiveEdge }
    var isScrubbing: Bool { session.isScrubbing }
    var position: Double { session.position }
    var duration: Double { session.duration }
    
    func togglePlayPause() { session.togglePlayPause() }
    func jump(by seconds: Double) { session.jump(by: seconds) }
    
    func goToLive() {
        session.goToLive()
        overlay.show()
    }
    
    func beginScrub() {
        session.beginScrub()
        overlay.holdForScrub(true)
    }
    
    func endScrub() {
        session.endScrub()
        overlay.holdForScrub(false)
    }
    
    func commitScrub(to seconds: Double) {
        session.commitScrub(to: seconds)
        overlay.holdForScrub(false)
    }
    
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
    
    var volume: Double {
        get { session.volume }
        set { session.volume = newValue }
    }
    
    var showsCameraControls: Bool { true }
    
    func didTapRecenter() { session.recenter() }
    
    var adMarkers: [YBVRSlider.AdMarker] { ads.adMarkers(contentDuration: session.duration) }
    
    var showsTestHarness: Bool { true }
}
