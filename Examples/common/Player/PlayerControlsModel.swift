//
//  PlayerControlsModel.swift
//  DemoApp
//
//  Shared by the iOS and visionOS demo apps.
//

import Foundation
import Observation
import YBVRAppleSDK

/**
 What a set of player controls needs from whatever is playing.
 
 Both pipelines the demos exercise - the YBVR streaming one behind `PlaybackSession`, and plain
 HLS behind `DirectPlayerViewModel` - end up driving the same transport UI.
 
 The camera and test-harness members only apply to the YBVR pipeline. Their defaults let a
 direct player conform without them, and `showsCameraControls` / `showsTestHarness` take that
 part of the UI off screen.
 */
@MainActor
protocol PlayerControlsModel: AnyObject, Observable {
    
    // MARK: Header
    
    var headerTitle: String { get }
    var headerSubtitle: String { get }
    
    // MARK: Overlay visibility
    
    /// The controls' own visibility and auto-hide timer.
    var overlay: OverlayVisibility { get }
    
    func handleTap()
    
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
    
    // MARK: Volume
    
    /// Playback volume, 0...1. Persisted by the caller, not the model.
    var volume: Double { get set }
    
    // MARK: Camera controls (YBVR pipeline only)
    
    var showsCameraControls: Bool { get }
    var isFullScreen: Bool { get set }
    var isCameraSelectorAppeared: Bool { get }
    func didTapRecenter()
    
    // MARK: Ad breaks and test harness (YBVR pipeline only)
    
    /// Scheduled ad breaks, drawn as markers on the scrub bar.
    var adMarkers: [YBVRSlider.AdMarker] { get }
    
    /// `true` when the overlay offers the recommendations / ad-schedule test controls.
    var showsTestHarness: Bool { get }
    var isRecommendationsVisible: Bool { get set }
    var isAdSchedulerVisible: Bool { get set }
}

extension PlayerControlsModel {
    
    var isOverlayVisible: Bool { overlay.isVisible }
    
    /// Reveals the controls and restarts the auto-hide countdown.
    func startOverlayTimer() { overlay.show() }
    
    var adMarkers: [YBVRSlider.AdMarker] { [] }
    
    var showsTestHarness: Bool { false }
    var isRecommendationsVisible: Bool {
        get { false }
        set { }
    }
    var isAdSchedulerVisible: Bool {
        get { false }
        set { }
    }
    
    var showsCameraControls: Bool { false }
    var isFullScreen: Bool {
        get { false }
        set { }
    }
    var isCameraSelectorAppeared: Bool { false }
    func didTapRecenter() { }
    
    var selectableAudioLanguages: [String] { availableAudioLanguages }
    var selectableSubtitlesLanguages: [String] { availableSubtitlesLanguages }
}
