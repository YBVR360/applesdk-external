//
//  PlaybackRestorePoint.swift
//  DemoApp
//
//  Shared by the iOS and visionOS demo apps.
//

import Foundation
import YBVRAppleSDK

/**
 Everything the viewer would notice losing when a session is rebuilt on another surface.
 
 A `YBVRPlayerManager` belongs to one rendering context, so swapping a window player for an
 immersive one means building a new manager and opening the stream again from the start.
 Captured before the old manager goes away and applied once the new one is streaming, this is
 what makes that swap read as the same video continuing rather than a new one beginning.
 */
struct PlaybackRestorePoint {
    
    let position: Double
    let isPlaying: Bool
    let cameraId: Int?
    let controlRoomCameraId: Int?
    let audioLanguage: String
    let subtitlesLanguage: String
    let playedAdBreakIds: Set<String>
    
    /// Captures what `session` is playing right now. `nil` when it has no player to capture.
    @MainActor
    init?(capturing session: PlaybackSession) {
        guard let player = session.player else { return nil }
        
        position = player.videoPosition.value
        isPlaying = session.isPlaying
        cameraId = player.currentCamera()?.id
        controlRoomCameraId = player.selectedControlRoomCameraValue?.id
        audioLanguage = player.currentAudioLanguagePublisher.value
        subtitlesLanguage = player.currentSubtitlesLanguagePublisher.value
        playedAdBreakIds = player.ads.playedIds.value
    }
    
    /// Tells a freshly attached player which ad breaks have already been seen.
    /// Has to run before the stream opens.
    @MainActor
    func markPlayedAdBreaks(on session: PlaybackSession) {
        guard !playedAdBreakIds.isEmpty else { return }
        session.player?.ads.markPlayed(playedAdBreakIds)
    }
    
    /// Puts the rest of the captured state back onto a session that has just started
    /// streaming again.
    ///
    /// Order matters: the camera is restored first because switching one rebuilds the item
    /// underneath, which would undo a seek made before it.
    @MainActor
    func apply(to session: PlaybackSession) async {
        if let cameraId, let camera = session.camera(withId: cameraId),
           camera.id != session.player?.currentCamera()?.id {
            await session.select(camera: camera)
        }
        
        if let controlRoomCameraId {
            session.restoreControlRoomCamera(id: controlRoomCameraId)
        }
        
        if session.canSeek, position > 0 {
            await session.waitUntilReady()
            session.seek(to: position)
        }
        
        if !audioLanguage.isEmpty {
            await session.setAudioLanguage(audioLanguage)
        }
        await session.setSubtitlesLanguage(subtitlesLanguage)
        
        if isPlaying { session.play() } else { session.pause() }
    }
}
