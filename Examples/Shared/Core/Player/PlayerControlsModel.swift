//
//  PlayerControlsModel.swift
//  Shared
//
//  Shared by the iOS and visionOS apps.
//

import Foundation
import Observation
import YBVRAppleSDK

/**
 What a set of player controls needs from whatever is playing.
 
 Anything that plays - the YBVR streaming pipeline behind `PlaybackSession`, or a plain HLS
 player - conforms to it and gets the same transport UI.
 */
@MainActor
protocol PlayerControlsModel: AnyObject, Observable {
    
    // MARK: Header
    
    var headerTitle: String { get }
    var headerSubtitle: String { get }
    
    // MARK: Playback
    
    var isLive: Bool { get }
    var canSeek: Bool { get }
    var isPlaying: Bool { get }
    var isAtLiveEdge: Bool { get }
    var isScrubbing: Bool { get }
    var position: Double { get }
    var duration: Double { get }
    
    func togglePlayPause()
    func jump(by seconds: Double)
    func goToLive()
    func beginScrub()
    func endScrub()
    func commitScrub(to seconds: Double)
    func requestDismiss()
    
    // MARK: Languages
    
    /// Every language the stream offers.
    var availableAudioLanguages: [String] { get }
    /// Subset of `availableAudioLanguages` selectable right now (a YBVR camera may carry fewer).
    var selectableAudioLanguages: [String] { get }
    var currentAudioLanguage: String { get }
    
    var availableSubtitlesLanguages: [String] { get }
    var selectableSubtitlesLanguages: [String] { get }
    var currentSubtitlesLanguage: String { get }
    
    func setAudioLanguage(_ language: String) async
    func setSubtitlesLanguage(_ language: String) async
    
    /// The subtitle cue to draw, or `nil` when there is none. The SDK draws no subtitles.
    var subtitleCue: String? { get }
    
    // MARK: Volume
    
    /// Playback volume, 0...1. Persisted by the caller, not the model.
    var volume: Double { get set }
}

extension PlayerControlsModel {
    
    var selectableAudioLanguages: [String] { availableAudioLanguages }
    var selectableSubtitlesLanguages: [String] { availableSubtitlesLanguages }
    
    var subtitleCue: String? { nil }
    
    /// Whether a 10 second jump back has anywhere to go.
    var canJumpBack: Bool { canSeek && position > 0.5 }
    
    /// Whether a 10 second jump forward has anywhere to go.
    var canJumpForward: Bool {
        guard canSeek else { return false }
        if isLive { return !isAtLiveEdge }
        return duration <= 0 || position < duration - 0.5
    }
}
