//
//  PlayerFactory.swift
//  Shared
//
//  Shared by the iOS and visionOS apps.
//

import Foundation
import YBVRAppleSDK

/**
 Builds `YBVRPlayerManager`s with the app's analytics already attached.
 
 A manager belongs to one rendering surface, so the demos build several over a session -
 iOS one per stream, visionOS one per surface it swaps to. The analytics tracker is the same
 for all of them and is built once here.
 */
@MainActor
final class PlayerFactory {
    
    private(set) var appName: String
    private(set) var analyticsConfig: AnalyticsConfig?
    
    /// The tracker handed to every manager this factory builds.
    private(set) var analytics: AnalyticsInterface?
    
    init(appName: String = "yeap", analyticsConfig: AnalyticsConfig? = nil) {
        self.appName = appName
        self.analyticsConfig = analyticsConfig
    }
    
    /// Adopts the configuration fetched at launch. Call before building the first player.
    func configure(appName: String, analyticsConfig: AnalyticsConfig?) {
        self.appName = appName
        self.analyticsConfig = analyticsConfig
        // Built from the old configuration; the next player builds one from this.
        analytics = nil
    }
    
    /**
     Builds a manager for `surfaceContext` and attaches analytics to it.
     
     - Parameter surfaceContext: The surface that will render it, or `nil` for the window
     player, which renders through the surface controller the manager hands back.
     */
    func makePlayer(surfaceContext: SurfaceContext? = nil,
                    videoConfig: VideoConfig = .defaultConfig) -> YBVRPlayerManager {
        let player = YBVRPlayerManager(videoConfig: videoConfig, surfaceContext: surfaceContext)
        attachAnalytics(to: player)
        return player
    }
    
    private func attachAnalytics(to player: YBVRPlayerManager) {
        guard let analyticsConfig else {
            print("[PlayerFactory] Player initialized without analytics")
            return
        }
        
        if analytics == nil {
            let tracker = Tracker(config: analyticsConfig, appName: appName)
            analytics = tracker
            Task {
                await tracker.setClient(TrackerClient(config: analyticsConfig))
                player.setAnalytics(analytics: tracker)
            }
            return
        }
        
        player.setAnalytics(analytics: analytics)
    }
}
