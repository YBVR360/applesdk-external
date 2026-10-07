//
//  CameraMapSupport.swift
//  DemoApp
//
//  Created by Manuel Tirado on 24.09.26.
//

import SwiftUI
import YBVRAppleSDK

// MARK: - Host

/**
 What the camera map reads and drives, supplied by whichever player shows it.
 
 The map belongs to no one player: visionOS drives it from `PlayerCoordinator`, iOS from
 `StreamViewModel`, and each picks a camera its own way. Set with `cameraMap(session:select:)`
 on the view the map sits in.
 */
struct CameraMapContext {
    /// The session whose cameras the map shows, and which it lights as playing.
    let session: PlaybackSession?
    /// Plays the camera a marker stands for.
    let select: @MainActor (ViewPoint) async -> Void
    
    /// With no host - a preview - the map draws its placeholder and picks nothing.
    static let none = CameraMapContext(session: nil, select: { _ in })
}

extension EnvironmentValues {
    @Entry var cameraMap: CameraMapContext = .none
}

extension View {
    /// Points the camera maps inside this view at `session`, picking cameras through `select`.
    func cameraMap(session: PlaybackSession,
                   select: @escaping @MainActor (ViewPoint) async -> Void) -> some View {
        environment(\.cameraMap, CameraMapContext(session: session, select: select))
    }
}

// MARK: - Image loading

/// Fetches the artwork signalling points at. `URLSession`'s own cache keeps a second call for
/// the same URL cheap, so callers can just ask again rather than holding a cache of their own.
enum CameraMapImage {
    
    static func load(_ url: URL?) async -> UIImage? {
        guard let url,
              let (data, response) = try? await URLSession.shared.data(from: url) else {
            return nil
        }
        
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    /// Fetches a set of icons at once, keyed by the URL string each came from. What fails to
    /// load is left out, so the caller falls back to its own art for it.
    static func load(_ urlStrings: Set<String>) async -> [String: UIImage] {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for urlString in urlStrings {
                group.addTask {
                    (urlString, await load(URL(string: urlString)))
                }
            }
            
            var loaded: [String: UIImage] = [:]
            for await (urlString, image) in group {
                loaded[urlString] = image
            }
            return loaded
        }
    }
}
