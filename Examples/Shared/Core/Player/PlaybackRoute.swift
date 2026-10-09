//
//  PlaybackRoute.swift
//  Shared
//
//  Shared by the iOS and visionOS apps.
//

import Foundation
import YBVRAppleSDK

/**
 Which player a video plays in.
 
 APMP content, and content its signaling declares DRM for, plays through `DirectPlayer`: the
 `YBVRPlayerManager` pipeline doesn't set up the signaling's FairPlay, and APMP is rendered by the
 system from the file's own projection metadata, as `DirectPlayerImmersiveScene` does on visionOS.
 Everything else plays through `YBVRPlayerManager`, handed the signaling already fetched here so
 it doesn't fetch it again.
 
 That includes YBVR's "clearkey" content. It isn't declared in the signaling, and `ApplePlayer`
 answers its key requests with `ClearKeyProvider`'s catalogue key in either pipeline.
 */
enum PlaybackRoute {
    case directPlayer(url: URL, drmKeyManager: DrmKeyManager?)
    case ybvr(signaling: SignalingInterface?)
    
    /// Decides where `video` plays, from the signaling fetched for it, or `nil` if there is none.
    init(video: Video, signaling: SignalingInterface?) {
        let drmKeyManager = signaling?.drmKeyManager()
        
        if let url = URL(string: video.urlString),
           Self.isApmp(video) || drmKeyManager != nil {
            self = .directPlayer(url: url, drmKeyManager: drmKeyManager)
        } else {
            self = .ybvr(signaling: signaling)
        }
    }
    
    /// Whether `video` is APMP, which is known without fetching its signaling. DRM is not.
    static func isApmp(_ video: Video) -> Bool {
        video.signalingVersion?.isApmpVideo ?? false
    }
    
    @MainActor
    static func fetchSignaling(for video: Video) async throws -> SignalingInterface? {
        let scout = YBVRPlayerManager(videoConfig: .defaultConfig, surfaceContext: nil)
        return try await scout.fetchSignalingFile(video: video)
    }
}

// MARK: - Content switching

extension PlaybackRoute {
    
    /// Why a video can't be switched to on a running `YBVRPlayerManager`.
    struct SwitchRefusal: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    
    /**
     Fetches the signaling for switching a running `YBVRPlayerManager` over to `video`.
     
     Throws `SwitchRefusal`, with a message to show the viewer, when the signaling can't be
     fetched or the video plays through `DirectPlayer`, which a content switch can't reach.
     */
    @MainActor
    static func signalingForSwitch(to video: Video) async throws -> SignalingInterface? {
        let signaling: SignalingInterface?
        do {
            signaling = try await fetchSignaling(for: video)
        } catch {
            throw SwitchRefusal(message: "Can't load \(video.name): \(error.localizedDescription)")
        }
        
        switch PlaybackRoute(video: video, signaling: signaling) {
        case .ybvr(let signaling):
            return signaling
        case .directPlayer(_, let drmKeyManager):
            let reason = drmKeyManager != nil ? "is DRM protected" : "is APMP content"
            throw SwitchRefusal(message: "\(video.name) \(reason) and plays in its own player.")
        }
    }
}
