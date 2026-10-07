//
//  DirectPlayerViewModel.swift
//  DemoApp
//
//  Created by Peter Angiuoli on 7/21/26.
//

import SwiftUI
import AVFoundation
import YBVRAppleSDK

/**
 Plain HLS playback, for content the signaling pipeline cannot carry - DRM above all.
 
 The same shape as the YBVR players: a façade over an engine plus the shared
 `OverlayVisibility`, conforming to `PlayerControlsModel` so the same controls drive it.
 What differs is only the engine underneath - `DirectPlayer` rather than a `PlaybackSession`
 around a `YBVRPlayerManager` - and so there are no cameras, no control room and no ads.
 */
@MainActor
@Observable
final class DirectPlayerViewModel {
    
    /// The engine. Already observable, so its transport state is read straight through.
    let player = DirectPlayer()
    
    /// The controls, and the idle timer that takes them away again.
    let overlay: OverlayVisibility
    
    // MARK: - Source
    
    /// URL of the video to play.
    var urlString = ""
    
    /// The Apple FairPlay certificate. Could equally be embedded in the app.
    var certificateURL = "https://tools.axinom.com/FPScert/fairplay.cer"
    
    /// The FairPlay licensing server, as hosted by the provider.
    var licenseServerURL = "https://drm-fairplay-licensing.axprod.net/AcquireLicense"
    
    /// Shown by the controls header. Set by whoever starts playback.
    var title = ""
    var subtitle = ""
    
    // MARK: - Screen state
    
    var isLoading = false
    var signalingError: String?
    var isScrubbing = false
    
    /// Set when the screen should close - the video ended, or the viewer asked to go back.
    var shouldDismiss = false
    
    var isActive: Bool { player.status != nil }
    
    /// Why nothing is playing, from either the signaling fetch or the player itself.
    var failure: String? {
        signalingError ?? player.error?.localizedDescription
    }
    
    init() {
#if os(visionOS)
        overlay = OverlayVisibility(autoHideInterval: 8)
#else
        overlay = OverlayVisibility(autoHideInterval: 5)
#endif
        // Controls stay up while playback is paused
        overlay.canAutoHide = { [weak self] in self?.player.isPlaying ?? false }
    }
}

// MARK: - Playback

extension DirectPlayerViewModel {
    
    /// `true` once the item played to the end - both demos close the player on it.
    var isVideoEnded: Bool { player.isVideoEnded }
    
    /// Playback volume, 0...1. Persisted by the caller, not the view model.
    var volume: Double {
        get { player.volume }
        set { player.volume = newValue }
    }
    
    /// Fetches the signaling file for `urlString` to find its DRM, then plays it.
    func play() async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else { return }
        
        isLoading = true
        do {
            try await player.open(url: url,
                                  fetchingDrmFromSignalingWith: certificateURL,
                                  licenseURL: licenseServerURL)
            signalingError = nil
        } catch {
            signalingError = "Failed to fetch signaling: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    /**
     Plays `url` directly, skipping the signaling fetch `play()` does.
     
     - Parameter drmKeyManager: The content's DRM. Leave it out for plain, unprotected streams.
     */
    func play(url: URL, drmKeyManager: DrmKeyManager? = nil) async {
        urlString = url.absoluteString
        player.drmConfig = drmKeyManager.map {
            DrmConfig(certificateURL: certificateURL,
                      licenseURL: licenseServerURL,
                      drmKeyManager: $0)
        }
        isLoading = true
        await player.open(url: url)
        isLoading = false
        signalingError = nil
    }
    
    func stop() {
        overlay.reset()
        shouldDismiss = false
        isScrubbing = false
        player.stop()
    }
    
    /// Seeks to `seconds`, clamped to what there is to seek within.
    func seek(to seconds: Double) {
        let duration = player.duration
        guard duration.isFinite, duration > 0 else {
            player.seek(to: max(0, seconds))
            return
        }
        player.seek(to: min(max(0, seconds), duration))
    }
}

// MARK: - PlayerControlsModel

extension DirectPlayerViewModel: PlayerControlsModel {
    
    var headerTitle: String { title }
    var headerSubtitle: String { subtitle }
    
    func handleTap() { overlay.toggle() }
    
    var isLive: Bool { player.isLive }
    
    var canSeek: Bool { player.duration > 0 }
    
    var isPlaying: Bool { player.isPlaying }
    var isAtLiveEdge: Bool { player.isAtLiveEdge }
    var position: Double { player.position }
    var duration: Double { player.duration }
    
    func togglePlayPause() {
        if player.isPlaying { player.pause() } else { player.play() }
    }
    
    func jump(by seconds: Double) {
        seek(to: player.position + seconds)
    }
    
    func goToLive() {
        seek(to: player.duration)
        overlay.show()
    }
    
    func beginScrub() {
        isScrubbing = true
        overlay.holdForScrub(true)
    }
    
    func endScrub() {
        isScrubbing = false
        overlay.holdForScrub(false)
    }
    
    func commitScrub(to seconds: Double) {
        endScrub()
        seek(to: seconds)
    }
    
    func requestDismiss() { shouldDismiss = true }
    
    var availableAudioLanguages: [String] { player.availableAudioLanguages }
    var currentAudioLanguage: String { player.currentAudioLanguage }
    var availableSubtitlesLanguages: [String] { player.availableSubtitlesLanguages }
    var currentSubtitlesLanguage: String { player.currentSubtitlesLanguage }
    
    func setAudioLanguage(_ language: String) async {
        await player.setAudioLanguage(language)
    }
    
    func setSubtitlesLanguage(_ language: String) async {
        await player.setSubtitlesLanguage(language)
    }
}
