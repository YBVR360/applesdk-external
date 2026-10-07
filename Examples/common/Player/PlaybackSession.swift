//
//  PlaybackSession.swift
//  DemoApp
//
//  Shared by the iOS and visionOS demo apps.
//

import SwiftUI
import Combine
import CoreMedia
import YBVRAppleSDK

/**
 One playback session: the player, everything it publishes, and the controls that drive it.
 
 A `YBVRPlayerManager` belongs to a single rendering surface, so a session is deliberately not
 the same thing as a manager. `attach(player:)` points the session at the manager rendering it
 right now, which lets visionOS swap window for immersive without the session - and the state
 the viewer would notice losing - going away. iOS attaches once and never swaps.
 
 Everything the SDK publishes through Combine is mirrored onto observable properties here, so
 views observe this one object instead of each juggling subscriptions of their own.
 
 Typical use:
 1. `begin(video:signaling:)` with the content to play.
 2. `attach(player:)` with a manager built for the surface that will render it.
 3. `start()` to open the stream.
 4. `end()` when the player goes away.
 */
@MainActor
@Observable
final class PlaybackSession {
    
    // MARK: - Content
    
    private(set) var video: Video?
    private(set) var signaling: SignalingInterface?
    
    /// The manager rendering this session, or `nil` between surfaces.
    private(set) var player: YBVRPlayerManager?
    
    /// Bumped every time `player` is replaced. For cached reset.
    private(set) var generation: Int = 0
    
    // MARK: - Transport
    
    /// Seconds into the content. Held still while the viewer is scrubbing.
    private(set) var position: Double = 0
    
    /// `0` until the player reports a real duration. Treat a non-positive duration as unknown.
    private(set) var duration: Double = 0
    
    private(set) var status: VideoStatus?
    private(set) var isAtLiveEdge: Bool = true
    private(set) var isScrubbing: Bool = false
    
    /// `true` once the content has played to its end.
    private(set) var hasEnded: Bool = false
    
    /// `true` for the duration of `switchContent(to:signaling:)`.
    private(set) var isSwitchingContent: Bool = false
    
    /// `true` between `start()` being called and the first frame being ready.
    private(set) var isLoading: Bool = false
    
    /// Set when opening or switching content failed. Cleared by the next attempt.
    private(set) var failure: String?
    
    // MARK: - Tracks
    
    /// The subtitle cue on screen.
    ///
    /// Only meaningful while `presentsSubtitles` is `true`: the Compositor Services renderer
    /// draws cues into the video itself, but the window player's Metal surface and the
    /// RealityKit one do not, and then it is the app that has to put them on screen.
    private(set) var subtitleCue: String?
    
    private(set) var audioLanguage: String = ""
    private(set) var subtitlesLanguage: String = ""
    
    // MARK: - Camera
    
    /// The camera the player is on, mirroring `YBVRPlayerManager.currentCamera()`.
    private(set) var camera: YBVRCamera?
    
    // MARK: - Volume
    
    /// Playback volume, 0...1. Re-applied after every camera change and content switch.
    var volume: Double = 1 {
        didSet { player?.volume = volume }
    }
    
    // MARK: - Callbacks
    
    /// Called once per content when it plays to its end. Hosts use it to close the player.
    /// Survives `end()`, so it only needs setting once.
    var onEnded: (() -> Void)?
    
    /// Called when playback fails once the stream is open.
    var onFailure: ((String) -> Void)?
    
    /// Dropped and rebuilt with every manager.
    private var cancellables = Set<AnyCancellable>()
    
    /// Guards against `onEnded` firing more than once per content.
    private var didReportEnded = false
    
    /// The last seek's target, until the player reports arriving there or `seekSettleTimeout`
    /// passes. A seek is not instant: for a moment the player keeps reporting where it was, and
    /// adopting that would send the seek bar back and then forward again.
    @ObservationIgnored private var pendingSeek: (target: Double, deadline: ContinuousClock.Instant)?
    
    /// How long a seek may take to be reported before positions are adopted regardless - so a
    /// seek that lands somewhere else (a live edge, a clamped end) cannot freeze the bar.
    private static let seekSettleTimeout: Duration = .milliseconds(1500)
    
    /// How close a reported position has to be to count as the seek having landed.
    private static let seekArrivalTolerance: Double = 1
    
    init() {}
}

// MARK: - Derived state

extension PlaybackSession {
    
    var isLive: Bool { video?.isLive ?? false }
    
    var canSeek: Bool {
        guard let video else { return false }
        return video.isTimeShiftingAllowed ?? true
    }
    
    var hasKnownDuration: Bool { duration > 0 }
    
    var isPlaying: Bool {
        switch status {
        case .paused: return false
        case .ready, .buffering, .none: return true
        }
    }
    
    var presentation: PlayerPresentation? { player?.playerPresentation }
    
    var controlRoomSelector: ControlRoomSelectorViewModel? {
        player?.controlRoomSelectorViewModel()
    }
    
    /// `true` when the app has to draw subtitle cues itself, because the surface does not.
    var presentsSubtitles: Bool { !(player?.surfaceRendersSubtitles ?? true) }
    
    /// Every audio language the stream offers.
    var availableAudioLanguages: [String] { player?.availableAudioLanguages ?? [] }
    
    /// The subset selectable right now - a given camera may carry fewer than the stream does.
    var selectableAudioLanguages: [String] {
        player?.getAvailableAudioLanguages(for: camera) ?? []
    }
    
    var availableSubtitlesLanguages: [String] { player?.availableSubtitlesLanguages ?? [] }
    
    var selectableSubtitlesLanguages: [String] {
        player?.getAvailableSubtitlesLanguages(for: camera) ?? []
    }
    
    var cameraId: Int? {
        camera?.id ?? presentation?.selectedViewPoint?.camID
    }
    
    /// Whether `viewPoint` stands for the camera playing.
    func isPlaying(_ viewPoint: ViewPoint) -> Bool {
        // The control room stays the one playing whichever of its mini screens is picked: each
        // plays a control room camera of its own, not only the one the view point names.
        if viewPoint.controlRoomID != nil, camera?.isControlRoom == true {
            return true
        }
        
        guard let camID = viewPoint.camID, let cameraId else { return false }
        return camID == cameraId
    }
}

// MARK: - Lifecycle

extension PlaybackSession {
    
    /// Points the session at the content to play. Call before building a player for it.
    func begin(video: Video, signaling: SignalingInterface? = nil) {
        self.video = video
        self.signaling = signaling
        resetContentState()
    }
    
    /// Adopts the manager that will render this session from now on.
    func attach(player newPlayer: YBVRPlayerManager) {
        player = newPlayer
        generation += 1
        newPlayer.volume = volume
        bind(to: newPlayer)
    }
    
    /// Drops the current manager without ending the session, so another surface can take over.
    /// `notifyEnded: false` keeps the SDK from reporting a real end of content.
    func detach(notifyEnded: Bool = false) {
        cancellables.removeAll()
        player?.stop(notifyEnded: notifyEnded)
        player = nil
        generation += 1
        subtitleCue = nil
    }
    
    /// Opens the stream on the attached player. Fetches signaling first when the caller did
    /// not supply any, and keeps it, so a later surface swap reopens without fetching again.
    @discardableResult
    func start() async -> Bool {
        guard let player, let video else { return false }
        
        isLoading = true
        failure = nil
        
        do {
            if signaling == nil {
                signaling = try await player.fetchSignalingFile(video: video)
            }
            try await player.startStream(video: video, signaling)
        } catch {
            isLoading = false
            failure = error.localizedDescription
            return false
        }
        
        guard self.player === player else {
            player.stop()
            return false
        }
        
        adoptCurrentCamera()
        player.volume = volume
        return true
    }
    
    /**
     Swaps the content without rebuilding the player.
     
     Keeps the session mounted: only the SDK's per-content state is rebuilt, so the surface
     and the underlying `AVPlayer` survive. `video` and `signaling` move with it, so a later
     surface swap reopens what is playing now rather than the content it replaced.
     
     - Parameter newVideo: The content to switch to.
     - Parameter newSignaling: Pre-fetched signaling, when the caller already has it.
     */
    @discardableResult
    func switchContent(to newVideo: Video, signaling newSignaling: SignalingInterface? = nil) async -> Bool {
        guard let player, newVideo != video else { return false }
        
        isSwitchingContent = true
        defer { isSwitchingContent = false }
        
        video = newVideo
        signaling = newSignaling
        resetContentState()
        isLoading = true
        
        do {
            try await player.switchContent(to: newVideo, newSignaling)
        } catch {
            isLoading = false
            failure = error.localizedDescription
            return false
        }
        
        bind(to: player)
        adoptCurrentCamera()
        player.volume = volume
        return true
    }
    
    /// Stops playback and releases everything the session holds.
    /// Keeps `onEnded`: hosts set it once and reuse the session for every video after this one.
    func end() {
        cancellables.removeAll()
        player?.stop()
        player = nil
        generation += 1
        video = nil
        signaling = nil
        resetContentState()
    }
    
    /// Clears everything that belongs to one piece of content, keeping what belongs to the
    /// session as a whole (volume, the attached player).
    private func resetContentState() {
        position = 0
        duration = 0
        status = nil
        isAtLiveEdge = true
        isScrubbing = false
        hasEnded = false
        didReportEnded = false
        pendingSeek = nil
        isLoading = false
        failure = nil
        subtitleCue = nil
        audioLanguage = ""
        subtitlesLanguage = ""
        camera = nil
    }
    
    private func adoptCurrentCamera() {
        guard let player else { return }
        guard let current = player.currentCamera() else { return }
        
        camera = current
        player.playerPresentation.setHeaderSubtitle(
            cameraName: current.displayableName,
            isSingleCam: player.cameras().count == 1
        )
    }
}

// MARK: - Player bindings

extension PlaybackSession {
    
    private func bind(to player: YBVRPlayerManager) {
        cancellables.removeAll()
        subtitleCue = nil
        
        player.videoDuration
            .receive(on: DispatchQueue.main)
            .filter { !$0.isNaN && $0 > 0 }
            .removeDuplicates()
            .sink { [weak self] in self?.duration = $0 }
            .store(in: &cancellables)
        
        player.videoPosition
            .receive(on: DispatchQueue.main)
            .filter { !$0.isNaN && $0 >= 0 }
            .sink { [weak self] value in
                // While scrubbing the thumb owns the position.
                guard let self, !self.isScrubbing else { return }
                if let pending = self.pendingSeek {
                    let hasArrived = abs(value - pending.target) <= Self.seekArrivalTolerance
                    guard hasArrived || ContinuousClock.now >= pending.deadline else { return }
                    self.pendingSeek = nil
                }
                self.position = value
            }
            .store(in: &cancellables)
        
        player.videoStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.status = status
                if status == .ready { self.isLoading = false }
            }
            .store(in: &cancellables)
        
        player.isAtLiveEdge
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] in self?.isAtLiveEdge = $0 }
            .store(in: &cancellables)
        
        player.isVideoEnded
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { [weak self] _ in self?.reportEnded() }
            .store(in: &cancellables)
        
        player.playbackError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self else { return }
                self.isLoading = false
                self.failure = error.localizedDescription
                self.onFailure?(error.localizedDescription)
            }
            .store(in: &cancellables)
        
        player.currentSubtitleCue
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] in self?.subtitleCue = $0 }
            .store(in: &cancellables)
        
        player.currentAudioLanguagePublisher
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] in self?.audioLanguage = $0 }
            .store(in: &cancellables)
        
        player.currentSubtitlesLanguagePublisher
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] in self?.subtitlesLanguage = $0 }
            .store(in: &cancellables)
    }
    
    private func reportEnded() {
        guard !didReportEnded, !isSwitchingContent else { return }
        didReportEnded = true
        hasEnded = true
        onEnded?()
    }
}

// MARK: - Transport controls

extension PlaybackSession {
    
    func play() { player?.play() }
    
    func pause() { player?.pause() }
    
    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }
    
    /// Seeks to `seconds`, clamped to the content. The upper bound is only applied once the
    /// real duration is known, so a jump near either end cannot send an out-of-range position.
    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        
        var target = max(seconds, 0)
        if hasKnownDuration { target = min(target, duration) }
        
        position = target
        pendingSeek = (target, ContinuousClock.now.advanced(by: Self.seekSettleTimeout))
        player?.seek(to: CMTimeMakeWithSeconds(target, preferredTimescale: 1000))
    }
    
    func jump(by seconds: Double) {
        seek(to: position + seconds)
    }
    
    func goToLive() {
        isAtLiveEdge = true
        seek(to: duration)
    }
    
    // MARK: Scrubbing
    
    func beginScrub() { isScrubbing = true }
    
    func endScrub() { isScrubbing = false }
    
    /// Ends a scrub with a single seek to where the thumb was let go.
    func commitScrub(to seconds: Double) {
        endScrub()
        seek(to: seconds)
    }
}

// MARK: - Camera controls

extension PlaybackSession {
    
    func select(camera newCamera: YBVRCamera) async {
        guard let player else { return }
        
        player.setHeaderSubtitle(camera: newCamera)
        await player.selectCamera(camera: newCamera)
        
        camera = newCamera
        player.volume = volume
    }
    
    func select(viewPoint: ViewPoint) async {
        guard let player, player.camera(for: viewPoint) != nil else { return }
        
        await player.didSelectCamera(from: viewPoint)
        
        camera = player.currentCamera()
        player.volume = volume
    }
    
    func recenter() {
        player?.recenterCameraPosition()
    }
    
    func rotate(radians: Double) {
        player?.applyRotation(radians: radians)
    }
    
    // MARK: Control room
    
    /// Shows or hides the control room's mini screens, where the surface draws them itself.
    func showControlRoomMiniScreens(_ visible: Bool) {
        player?.showCRMiniScreens(visible)
    }
    
    /// Picks the control room feed at `index`, keeping the selector's own state in step.
    func selectControlRoomCamera(atIndex index: Int) {
        guard let selector = controlRoomSelector else { return }
        
        let cameras = selector.controlRoomCameras
        guard cameras.indices.contains(index) else { return }
        
        selector.userDidSelectControlRoom(camera: cameras[index])
        selector.selectedIndex = index
    }
    
    /// The camera carrying `id`.
    func camera(withId id: Int) -> YBVRCamera? {
        guard let player else { return nil }
        return player.cameras().first { $0.id == id }
        ?? player.controlRoomCameras().first { $0.id == id }
    }
    
    /// Restores a control room selection by camera id, without going through a user gesture.
    /// Used when a session is rebuilt on another surface.
    func restoreControlRoomCamera(id: Int) {
        guard let player,
              let selector = controlRoomSelector,
              let index = selector.controlRoomCameras.firstIndex(where: { $0.id == id })
                else {
            return
        }
        
        let restored = selector.controlRoomCameras[index]
        selector.selectedControlRoomCamera = restored
        selector.selectedIndex = index
        player.selectControlRoomCamera(restored)
    }
}

// MARK: - Waiting

extension PlaybackSession {
    
    /// Suspends until the player reports its first frame, or `timeout` elapses.
    ///
    /// A freshly built player cannot be seeked before it has an item to seek within, so a
    /// session being restored onto another surface has to wait for one.
    func waitUntilReady(timeout: Duration = .seconds(10)) async {
        guard let player else { return }
        
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while player.videoStatus.value != .ready, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
            if Task.isCancelled { return }
        }
    }
}

// MARK: - Language controls

extension PlaybackSession {
    
    func setAudioLanguage(_ language: String) async {
        await player?.setAudioLanguage(language: language)
    }
    
    /// An empty language turns subtitles off.
    func setSubtitlesLanguage(_ language: String) async {
        await player?.setSubtitlesLanguage(language: language)
    }
}
