//
//  AppEnvironment.swift
//  DemoApp
//
//  Shared by the iOS and visionOS demo apps.
//

import Foundation
import YBVRAppleSDK

/**
 What both demos need before anything can play: the account configuration fetched at launch,
 a factory that turns it into players, and the list of videos on offer.
 
 Put into the SwiftUI environment once from the app entry point. Everything else about playing
 a video - the session, the controls, the scenes - is built on top of this per platform.
 */
@MainActor
@Observable
final class AppEnvironment {
    
    private(set) var configuration: YBVRAppConfiguration?
    
    /// Builds players with this app's analytics attached.
    let players = PlayerFactory()
    
    /// The videos the demo offers.
    let catalog = VideoCatalog()
    
    /// `true` once `initialize()` has run, whether or not the configuration came back. The
    /// demos play without analytics rather than refusing to start.
    private(set) var isReady = false
    
    /// Why the configuration could not be fetched, or `nil` when it was.
    private(set) var configurationFailure: String?
    
    init() {}
    
    /// Fetches the app configuration and hands it to the player factory.
    @discardableResult
    func initialize(appName: String = "yeap") async -> Self {
        do {
            let configuration = try await YBVRAppConfigurationLoader().load(appName: appName)
            self.configuration = configuration
            configurationFailure = nil
            players.configure(appName: appName, analyticsConfig: configuration.analyticsConfig)
        } catch {
            configurationFailure = error.localizedDescription
            print("[AppEnvironment] Failed to fetch app configuration: \(error)")
            players.configure(appName: appName, analyticsConfig: nil)
        }
        
        isReady = true
        return self
    }
}
