//
//  PlayerCoordinator.swift
//  DemoApp
//

import SwiftUI
import Combine
import CompositorServices
import YBVRAppleSDK

/**
 Drives one playback session across the scenes visionOS can render it in.
 
 A `YBVRPlayerManager` belongs to a single rendering surface, so playing the same video in a
 window and then immersively means building two of them. The session outlives that swap -
 `PlaybackSession` holds what is playing and everything it publishes - and this coordinator is
 what knows about the surfaces: which scene a video belongs in, how to hand the session a
 player built for it, and what has to be put back afterwards.
 
 Playback itself lives in `session`, ad-break testing in `ads`, and the auto-hiding controls
 window in `overlay`, all three shared with the iOS demo.
 */
@MainActor
@Observable
final class PlayerCoordinator {
    
    /// Where the session is being rendered.
    enum Surface: String {
        case window
        case immersive
        
        var other: Surface { self == .window ? .immersive : .window }
    }
    
    // MARK: - Shared pieces
    
    /// The player and everything it publishes.
    let session = PlaybackSession()
    /// Ad breaks scheduled by hand, for exercising ad insertion.
    let ads = AdHarness()
    /// The controls window, and the idle timer that takes it away again.
    let overlay = OverlayVisibility(autoHideInterval: 8)
    
    private let environment: AppEnvironment
    
    // MARK: - Surface
    
    private(set) var surface: Surface = .immersive
    /// `true` from the moment a surface swap is asked for until the new player is streaming.
    private(set) var isSwitchingSurface = false
    
    private var restorePoint: PlaybackRestorePoint?
    
    // MARK: - Screen state
    
    /// `true` while the control room's mini screens are on screen.
    var showControlRoomSelector = false {
        didSet {
            guard oldValue != showControlRoomSelector else { return }
            session.showControlRoomMiniScreens(showControlRoomSelector)
        }
    }
    var showRecommendations = false
    /// Why the last content switch was refused, or `nil`. Shown by the recommendations panel.
    var switchFailure: String?
    /// Set when opening a stream threw. Surfaced by whichever scene was opening it.
    var error: Error?
    /// `true` once the session is over and the scenes should close and hand back to the list.
    var isFinished = false
    /// `true` while a scene is presenting this session, so the list does not open a second one.
    private(set) var isPresenting = false
    
    /// `true` from the moment a scene builds a player until the session is over - which
    /// `isFinished` marks as soon as the viewer asks to leave, before teardown has run.
    var isSessionOnScreen: Bool { isPresenting && !isFinished }
    
    // MARK: - Interactables
    
    private(set) var interactableState: InteractableState?
    
    /// Flipped on to take every open interactable window down at once - when content is
    /// swapped underneath them, or the session ends.
    var dismissAllInteractableViews = false
    
    private var interactableSubscriber: AnyCancellable?
    
    // MARK: - Init
    
    init(environment: AppEnvironment) {
        self.environment = environment
        
        overlay.canAutoHide = { [weak self] in self?.session.isPlaying ?? false }
        
        overlay.canShow = { [weak self] in self?.isSessionOnScreen ?? false }
        
        ads.onPlaybackChanged = { [weak self] playback in
            guard let self else { return }
            self.overlay.setPinned(playback != nil, reason: "ad")
        }
        
        session.onEnded = { [weak self] in
            self?.isFinished = true
        }
        
        session.onFailure = { [weak self] message in
            guard let self, self.isSessionOnScreen else { return }
            self.error = PlaybackError(message: message)
            self.isFinished = true
        }
    }
}

// MARK: - Scene routing

extension PlayerCoordinator {
    
    var immersiveSceneId: String { ImmersiveInteractionScene.id }
    var windowSceneId: String { SceneID.windowPlayer }
    var currentSceneId: String {
        surface == .window ? windowSceneId : immersiveSceneId
    }
}

// MARK: - Session lifecycle

extension PlayerCoordinator {
    
    /// Points the coordinator at the content to play. Call before opening a scene for it.
    func begin(video: Video, signaling: SignalingInterface? = nil) {
        session.begin(video: video, signaling: signaling)
        surface = .immersive
        restorePoint = nil
        isSwitchingSurface = false
        isFinished = false
        switchFailure = nil
        error = nil
        showControlRoomSelector = false
    }
    
    // MARK: Surfaces
    
    /// For the window player, which renders through the manager's own surface controller.
    func prepareForWindow() {
        makePlayer(surfaceContext: nil)
    }
    
    /// For the Compositor Services renderer, which draws the video itself.
    func prepareForImmersive(layerRenderer: LayerRenderer) {
        makePlayer(surfaceContext: VisionSurfaceContext(layerRenderer: layerRenderer))
    }
    
    private func makePlayer(surfaceContext: SurfaceContext?) {
        isPresenting = true
        
        let player = environment.players.makePlayer(surfaceContext: surfaceContext)
        session.attach(player: player)
        ads.attach(to: player)
        
        // A surface swap builds a player that knows nothing of what was on screen.
        session.showControlRoomMiniScreens(showControlRoomSelector)
        restorePoint?.markPlayedAdBreaks(on: session)
    }
    
    /// Opens the stream on whichever player was just built, then puts back anything a surface
    /// swap had to leave behind.
    @discardableResult
    func startPlayback() async -> Bool {
        defer { isSwitchingSurface = false }
        
        guard await session.start() else {
            if error == nil, let failure = session.failure {
                error = PlaybackError(message: failure)
            }
            if isSessionOnScreen {
                isFinished = true
            }
            return false
        }
        
        if let restorePoint {
            self.restorePoint = nil
            await restorePoint.apply(to: session)
        }
        
        subscribeToInteractables()
        overlay.show()
        return true
    }
    
    /// Ends the session and releases everything it holds.
    func end() {
        dismissAllInteractableViews = true
        interactableSubscriber?.cancel()
        interactableSubscriber = nil
        
        overlay.reset()
        ads.detach()
        session.end()
        
        showRecommendations = false
        showControlRoomSelector = false
        switchFailure = nil
        restorePoint = nil
        isSwitchingSurface = false
        isPresenting = false
    }
    
    struct PlaybackError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}

// MARK: - Surface switching

extension PlayerCoordinator {
    
    /// Starts a swap to the other surface.
    ///
    /// Captures what is playing, lets the current player go, and leaves the session without one
    /// until the new scene builds it. The caller opens and closes the scenes; `currentSceneId`
    /// names the one to open once this returns.
    func beginSurfaceSwitch(to newSurface: Surface) -> Bool {
        guard !isSwitchingSurface, session.player != nil, newSurface != surface else {
            return false
        }
        
        isSwitchingSurface = true
        restorePoint = PlaybackRestorePoint(capturing: session)
        
        // Not a real end of content: the same video is about to reopen on the other surface.
        session.detach(notifyEnded: false)
        
        surface = newSurface
        return true
    }
}

// MARK: - Content switching

extension PlayerCoordinator {
    
    /// The videos the session can switch to. APMP videos play through `DirectPlayer`, which a
    /// content switch can't reach, so they are left out.
    var switchableVideos: [Video] {
        guard let current = session.video else { return [] }
        
        return environment.catalog.videos.filter {
            $0 != current && !PlaybackRoute.isApmp($0)
        }
    }
    
    /// Swaps the content playing in the open scene. The session keeps its player and surface.
    @discardableResult
    func switchTo(video newVideo: Video) async -> Bool {
        guard session.player != nil,
              newVideo != session.video,
              !session.isSwitchingContent
                else { return false }
        
        switchFailure = nil
        
        // Content `DirectPlayer` plays is in a scene of its own, which this pipeline has no
        // way to reach - refuse rather than switch into silence.
        let signaling: SignalingInterface?
        do {
            signaling = try await PlaybackRoute.signalingForSwitch(to: newVideo)
        } catch {
            switchFailure = error.localizedDescription
            return false
        }
        
        // Let the outgoing content's interactables go before the new ones arrive.
        dismissAllInteractableViews = true
        
        guard await session.switchContent(to: newVideo, signaling: signaling) else {
            switchFailure = session.failure
            // The old content keeps playing and keeps its subscription. Lower the flag, or the
            // next dismiss-all - `end()` included - is no change and closes nothing.
            dismissAllInteractableViews = false
            return false
        }
        
        showControlRoomSelector = false
        // The panel has done its job; a failed switch leaves it up to show why.
        showRecommendations = false
        
        ads.reapplyForNewContent()
        subscribeToInteractables()
        overlay.show()
        
        return true
    }
}

// MARK: - Cameras

extension PlayerCoordinator {
    
    /// Plays the camera a map view point stands for, bringing the control room's mini screens
    /// up when what was picked is a control room camera.
    func selectViewPoint(_ viewPoint: ViewPoint) async {
        await session.select(viewPoint: viewPoint)
        
        guard let camera = session.camera else { return }
        showControlRoomSelector = camera.isControlRoom
        overlay.show()
    }
    
    /// Handles pinches landing anywhere in the immersive space: any pinch brings the controls
    /// back, and one that lands on a control room mini screen plays that camera.
    func handlePinches(_ eventCollection: SpatialEventCollection) {
        for event in eventCollection {
            guard event.kind == .indirectPinch else { continue }
            overlay.show()
            
            guard event.phase == .ended else { continue }
            
            // Prefer the tracking area identifier (set when hover effects are active): it
            // avoids ray casting entirely. The identifier is (cameraIndex + 1).
            let trackId = event.trackingAreaIdentifier.rawValue
            if trackId > 0 {
                session.selectControlRoomCamera(atIndex: Int(trackId) - 1)
                continue
            }
            
            // Fall back to ray casting for devices / builds without tracking area support.
            guard let ray = event.selectionRay else { continue }
            let direction = simd_float3(Float(ray.direction.x),
                                        Float(ray.direction.y),
                                        Float(ray.direction.z))
            guard let index = session.player?.hitTestCRMiniScreen(rayDirection: direction) else {
                continue
            }
            session.selectControlRoomCamera(atIndex: index)
        }
    }
}

// MARK: - Interactables

extension PlayerCoordinator {
    
    /// Watches the SDK for interactable graphics to show and dismiss. Re-subscribed on every
    /// content switch, since the publisher belongs to the content.
    func subscribeToInteractables() {
        dismissAllInteractableViews = false
        interactableSubscriber = session.player?
            .interactablePublisher
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.interactableState = state
            }
    }
}

// MARK: - PlayerControlsModel

/// Lets the same controls drive the YBVR pipeline and the Direct Player.
extension PlayerCoordinator: PlayerControlsModel {
    
    var headerTitle: String { session.video?.name ?? "" }
    var headerSubtitle: String { session.camera?.name ?? "" }
    
    func handleTap() { overlay.show() }
    
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
    
    var volume: Double {
        get { session.volume }
        set { session.volume = newValue }
    }
    
    var showsCameraControls: Bool { true }
    
    func didTapRecenter() { session.recenter() }
    
    var adMarkers: [YBVRSlider.AdMarker] { ads.adMarkers(contentDuration: session.duration) }
    
    var showsTestHarness: Bool { true }
    
    var isRecommendationsVisible: Bool {
        get { showRecommendations }
        set { showRecommendations = newValue }
    }
}
