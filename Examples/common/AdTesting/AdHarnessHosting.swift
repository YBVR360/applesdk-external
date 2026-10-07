//
//  AdHarnessHosting.swift
//  DemoApp
//

import Foundation
import YBVRAppleSDK

/**
 What the shared ad-testing views need from whatever holds the ad state.
 
 Both demos hold it on `AdHarness`
 */
@MainActor
protocol AdHarnessHosting: AnyObject, Observable {
    
    /// The form's working copy, turned into breaks by `applyAdTestSchedule()`.
    var adTestSchedule: AdTestSchedule { get }
    
    /// Breaks currently handed to the player.
    var scheduledAdBreaks: [YBVRAdBreak] { get }
    
    /// Ids of breaks already played, so the list can dim them.
    var playedAdBreakIds: Set<String> { get }
    
    /// Non-nil while an ad creative is on screen.
    var adPlayback: YBVRAdPlayback? { get }
    
    var adPosition: Double { get }
    var adDuration: Double { get }
    var canSkipAd: Bool { get }
    var skipAvailableIn: Double { get }
    
    var playsMissedMidRollsOnSeek: Bool { get set }
    
    func applyAdTestSchedule()
    func removeScheduledBreak(id: String)
    func clearAdBreaks()
    func skipCurrentAd()
}

extension AdHarnessHosting {
    
    var isPlayingAd: Bool { adPlayback != nil }
    
    // MARK: - Labels for the ad on screen
    
    /// Progress through the ad on screen, 0...1.
    var adProgress: Double {
        guard adDuration > 0 else { return 0 }
        return min(1, max(0, adPosition / adDuration))
    }
    
    /// `"2 of 3"` while a pod plays, `nil` for a single creative.
    var adPodLabel: String? {
        guard let adPlayback else { return nil }
        let total = adPlayback.adBreak.creatives.count
        guard total > 1 else { return nil }
        return "\(adPlayback.creativeIndex + 1) of \(total)"
    }
    
    var adCueLabel: String {
        adPlayback?.adBreak.cue.displayLabel ?? ""
    }
    
    /// Seconds left on the skip gate, floored at 1 so it never reads "skip in 0".
    var skipCountdown: Int {
        max(1, Int(skipAvailableIn.rounded(.up)))
    }
}
