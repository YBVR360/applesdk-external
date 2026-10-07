//
//  AdHarness.swift
//  DemoApp
//

import Foundation
import Combine
import YBVRAppleSDK

/**
 Ad-break test state, shared by the iOS and visionOS demos.
 
 The player manager only exists once playback starts, so a schedule built in the setup sheet
 has nowhere to go yet. This holds it as the source of truth and pushes it at the
 manager as soon as one is attached, which keeps "configure before playing" and "configure
 while playing" on the same path.
 
 Mirrors `YBVRPlayerManager.ads` onto observable properties so the windows can bind to it
 without each of them juggling Combine.
 */
@MainActor
@Observable
final class AdHarness: AdHarnessHosting {
    
    let adTestSchedule = AdTestSchedule()
    
    private(set) var scheduledAdBreaks: [YBVRAdBreak] = []
    
    // MARK: Playback state
    
    private(set) var adPlayback: YBVRAdPlayback?
    private(set) var adPosition: Double = 0
    private(set) var adDuration: Double = 0
    private(set) var canSkipAd: Bool = false
    private(set) var skipAvailableIn: Double = 0
    private(set) var playedAdBreakIds: Set<String> = []
    
    /// `true` while a re-armed ad is being fetched and content is still on screen.
    private(set) var isPreparingAdBreak: Bool = false
    
    var playsMissedMidRollsOnSeek: Bool = true {
        didSet { player?.ads.playsMissedMidRollsOnSeek = playsMissedMidRollsOnSeek }
    }
    
    private var isStagingForNextContent = false
    private var scheduleBeforeStaging: [YBVRAdBreak] = []
    
    var adBreaksInForce: [YBVRAdBreak] {
        isStagingForNextContent ? scheduleBeforeStaging : scheduledAdBreaks
    }
    
    /// Called whenever an ad break takes the screen or gives it back. Non-nil playback means
    /// an ad is on screen.
    var onPlaybackChanged: ((YBVRAdPlayback?) -> Void)?
    
    private weak var player: YBVRPlayerManager?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle
    
    /// Binds to a freshly created manager and hands it whatever is already scheduled.
    ///
    /// Call before `startStream(video:)`: the SDK re-applies the schedule when it builds its
    /// player, so breaks set here survive the stream opening.
    func attach(to player: YBVRPlayerManager) {
        guard self.player !== player else { return }
        
        cancellables.removeAll()
        self.player = player
        
        player.ads.playsMissedMidRollsOnSeek = playsMissedMidRollsOnSeek
        player.ads.schedule(scheduledAdBreaks)
        
        bind(player.ads)
    }
    
    /// Drops playback state but keeps the schedule, so returning to the list and picking
    /// another video reuses what was set up.
    func detach() {
        cancelStaging()
        
        cancellables.removeAll()
        player = nil
        
        resetPlaybackState()
    }
    
    /// Hands the schedule to the same manager after a content switch, which drops it.
    func reapplyForNewContent() {
        resetPlaybackState()
        
        player?.ads.playsMissedMidRollsOnSeek = playsMissedMidRollsOnSeek
        player?.ads.schedule(scheduledAdBreaks)
    }
    
    private func resetPlaybackState() {
        adPlayback = nil
        adPosition = 0
        adDuration = 0
        canSkipAd = false
        skipAvailableIn = 0
        isPreparingAdBreak = false
        playedAdBreakIds = []
    }
    
    private func bind(_ ads: YBVRAdController) {
        ads.playback
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playback in
                guard let self else { return }
                self.adPlayback = playback
                self.onPlaybackChanged?(playback)
            }
            .store(in: &cancellables)
        
        mirror(ads.position, to: \.adPosition)
        mirror(ads.duration, to: \.adDuration)
        mirror(ads.canSkip, to: \.canSkipAd)
        mirror(ads.skipAvailableIn, to: \.skipAvailableIn)
        mirror(ads.isPreparing, to: \.isPreparingAdBreak)
        mirror(ads.playedIds, to: \.playedAdBreakIds)
    }
    
    private func mirror<T>(_ publisher: CurrentValueSubject<T, Never>,
                           to keyPath: ReferenceWritableKeyPath<AdHarness, T>) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?[keyPath: keyPath] = $0 }
            .store(in: &cancellables)
    }
    
    // MARK: - Schedule editing
    
    /// Adds the breaks the form currently describes, keeping what is already scheduled.
    func applyAdTestSchedule() {
        let existingIds = Set(scheduledAdBreaks.map(\.id))
        let added = adTestSchedule.breaks().filter { !existingIds.contains($0.id) }
        guard !added.isEmpty else { return }
        
        push(scheduledAdBreaks + added)
    }
    
    func removeScheduledBreak(id: String) {
        push(scheduledAdBreaks.filter { $0.id != id })
    }
    
    func clearAdBreaks() {
        push([])
    }
    
    func beginStagingForNextContent() {
        guard !isStagingForNextContent else { return }
        
        scheduleBeforeStaging = scheduledAdBreaks
        isStagingForNextContent = true
        scheduledAdBreaks = []
    }
    
    func endStaging() {
        isStagingForNextContent = false
        scheduleBeforeStaging = []
    }
    
    func cancelStaging() {
        guard isStagingForNextContent else { return }
        
        isStagingForNextContent = false
        scheduledAdBreaks = scheduleBeforeStaging
        scheduleBeforeStaging = []
    }
    
    // MARK: - Seek bar
    
    /// Where the breaks in force fall on a seek bar, with the ones already played marked so
    /// the bar can fade them.
    func adMarkers(contentDuration: Double) -> [YBVRSlider.AdMarker] {
        guard contentDuration > 0 else { return [] }
        
        return adBreaksInForce.compactMap { adBreak in
            guard let position = adBreak.cue.timelinePosition(contentDuration: contentDuration) else {
                return nil
            }
            return YBVRSlider.AdMarker(position: position,
                                       played: playedAdBreakIds.contains(adBreak.id))
        }
    }
    
    // MARK: - Playback
    
    /// End the ad on screen. The SDK refuses while the break's skip offset has not elapsed.
    func skipCurrentAd() {
        player?.ads.cancelCurrentBreak()
    }
    
    private func push(_ breaks: [YBVRAdBreak]) {
        scheduledAdBreaks = breaks
        guard !isStagingForNextContent else { return }
        player?.ads.schedule(breaks)
    }
}
