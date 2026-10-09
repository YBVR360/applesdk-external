//
//  DirectPlaybackModel.swift
//  Shared
//
//  Shared by the iOS and visionOS apps.
//

import SwiftUI
import YBVRAppleSDK

/**
 Plays a video through the SDK's `DirectPlayer`: APMP content, which the system renders from the
 file's own projection metadata, and FairPlay-protected content. `PlaybackRoute` says which
 videos go here; everything else plays through `YBVRPlayerManager`.
 
 Conforms to `PlayerControlsModel`, so the same controls drive it as the YBVR player.
 */
@MainActor
@Observable
final class DirectPlaybackModel {
    
    /// The FairPlay certificate and licence server for protected content - your DRM provider's.
    static let fairPlayCertificateURL = "https://tools.axinom.com/FPScert/fairplay.cer"
    static let fairPlayLicenseURL = "https://drm-fairplay-licensing.axprod.net/AcquireLicense"
    
    let player = DirectPlayer()
    
    private(set) var title = ""
    /// Set when the player should close - the viewer asked to go back.
    var shouldDismiss = false
    /// Why the video stopped, once its player has closed. Shown by the list.
    var failure: PlayerNotifications.Modal?
    
    private(set) var isScrubbing = false
    
    /// visionOS: whether the controls window is open, so a pinch knows to bring it back.
    var isControlsWindowOpen = false
    
    /// Opens `url`, with FairPlay set up when `drmKeyManager` says the content is protected, and
    /// starts on its first audio track.
    func play(video: Video, url: URL, drmKeyManager: DrmKeyManager?) async {
        title = video.name
        shouldDismiss = false
        failure = nil
        
        player.drmConfig = drmKeyManager.map {
            DrmConfig(certificateURL: Self.fairPlayCertificateURL,
                      licenseURL: Self.fairPlayLicenseURL,
                      drmKeyManager: $0)
        }
        await player.open(url: url)
        
        if let firstAudio = player.availableAudioLanguages.first {
            await player.setAudioLanguage(firstAudio)
        }
    }
    
    func stop() {
        isScrubbing = false
        player.stop()
    }
}

// MARK: - PlayerControlsModel

extension DirectPlaybackModel: PlayerControlsModel {
    
    var headerTitle: String { title }
    var headerSubtitle: String { "" }
    
    var isLive: Bool { player.isLive }
    var canSeek: Bool { player.duration > 0 }
    var isPlaying: Bool { player.isPlaying }
    var isAtLiveEdge: Bool { player.isAtLiveEdge }
    var position: Double { player.position }
    var duration: Double { player.duration }
    
    func togglePlayPause() {
        if player.isPlaying { player.pause() } else { player.play() }
    }
    
    func jump(by seconds: Double) { seek(to: player.position + seconds) }
    func goToLive() { seek(to: player.duration) }
    
    func beginScrub() { isScrubbing = true }
    func endScrub() { isScrubbing = false }
    
    func commitScrub(to seconds: Double) {
        isScrubbing = false
        seek(to: seconds)
    }
    
    func requestDismiss() { shouldDismiss = true }
    
    var availableAudioLanguages: [String] { player.availableAudioLanguages }
    var currentAudioLanguage: String { player.currentAudioLanguage }
    var availableSubtitlesLanguages: [String] { player.availableSubtitlesLanguages }
    var currentSubtitlesLanguage: String { player.currentSubtitlesLanguage }
    
    func setAudioLanguage(_ language: String) async { await player.setAudioLanguage(language) }
    func setSubtitlesLanguage(_ language: String) async { await player.setSubtitlesLanguage(language) }
    
    var volume: Double {
        get { player.volume }
        set { player.volume = newValue }
    }
    
    /// Seeks to `seconds`, kept within what there is to seek.
    private func seek(to seconds: Double) {
        let duration = player.duration
        player.seek(to: duration > 0 ? min(max(0, seconds), duration) : max(0, seconds))
    }
}
