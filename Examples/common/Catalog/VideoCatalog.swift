//
//  VideoCatalog.swift
//  DemoApp
//
//  Shared by the iOS and visionOS demo apps.
//

import Foundation
import UniformTypeIdentifiers
import YBVRAppleSDK

/**
 The list of videos the demo offers.
 
 Loads `VideoList.plist` from the bundle at launch and can be pointed at another file the
 viewer picks, so a tester can drop in their own list without a rebuild. Both `.plist` and
 `.json` are accepted; the file's own type decides which decoder runs.
 */
@MainActor
@Observable
final class VideoCatalog {
    
    private(set) var videos: [Video] = []
    
    /// How each video on screen is watched, by id - what its card labels it with.
    private(set) var experiences: [Video.ID: Experience] = [:]
    
    /// Why the last load failed, or `nil` when the list on screen is the one that was asked for.
    private(set) var loadFailure: String?
    
    /// `true` while the bundled list is on screen, as opposed to one the viewer imported.
    private(set) var isDefaultList = true
    
    /// The bundled list's file name. Both demos ship the same one.
    static let bundledFileName = "VideoList.plist"
    
    init() {
        loadBundledList()
    }
    
    // MARK: - Loading
    
    /// Loads the list shipped with the app, replacing whatever was on screen.
    func loadBundledList() {
        guard let url = Bundle.main.url(forResource: Self.bundledFileName, withExtension: nil) else {
            videos = []
            loadFailure = "\(Self.bundledFileName) is missing from the bundle."
            return
        }
        
        do {
            (videos, experiences) = try Self.decodeVideos(at: url)
            loadFailure = nil
            isDefaultList = true
        } catch {
            videos = []
            experiences = [:]
            loadFailure = error.localizedDescription
        }
    }
    
    /// Loads a list the viewer picked. Leaves the current list alone when the file cannot be
    /// read, so a bad pick never empties the screen.
    ///
    /// - Returns: `true` when the imported list is now on screen.
    @discardableResult
    func load(contentsOf url: URL) -> Bool {
        do {
            (videos, experiences) = try Self.decodeVideos(at: url)
            loadFailure = nil
            isDefaultList = false
            return true
        } catch {
            loadFailure = error.localizedDescription
            return false
        }
    }
    
    /// Acknowledges a failure without touching the list on screen
    func clearFailure() {
        loadFailure = nil
    }
    
    // MARK: - Decoding
    
    enum CatalogError: LocalizedError {
        case unsupportedFileType
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFileType:
                return "Unsupported file type. Use a .json or .plist file holding Video items."
            }
        }
    }
    
    /// The videos in the file, and how each is watched. Read in two passes over the same data:
    /// `Video` belongs to the SDK and has no field for the experience, so it is read from each
    /// entry on its own.
    private static func decodeVideos(at url: URL) throws -> ([Video], [Video.ID: Experience]) {
        let data = try Data(contentsOf: url)
        
        let videos: [Video]
        let entries: [CatalogEntry]
        switch try contentType(of: url) {
        case .json:
            videos = try JSONDecoder().decode([Video].self, from: data)
            entries = (try? JSONDecoder().decode([CatalogEntry].self, from: data)) ?? []
        case .propertyList:
            videos = try PropertyListDecoder().decode([Video].self, from: data)
            entries = (try? PropertyListDecoder().decode([CatalogEntry].self, from: data)) ?? []
        default:
            throw CatalogError.unsupportedFileType
        }
        
        var experiences: [Video.ID: Experience] = [:]
        for (index, video) in videos.enumerated() {
            let listed = entries.indices.contains(index) ? entries[index].experience : nil
            experiences[video.id] = listed ?? Experience(inferredFrom: video)
        }
        return (videos, experiences)
    }
    
    /// The file's declared type, falling back to its extension when the file system has no
    /// answer - which is what happens for a security-scoped URL handed over by the importer.
    private static func contentType(of url: URL) throws -> UTType {
        if let declared = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return declared
        }
        
        switch url.pathExtension.lowercased() {
        case "json": return .json
        case "plist": return .propertyList
        default: throw CatalogError.unsupportedFileType
        }
    }
}

// MARK: - Experience

extension VideoCatalog {
    
    /// How a video is watched, as the list labels it.
    ///
    /// Set per entry with an `experience` key - `single-view` or `immersive` - since nothing on
    /// the `Video` itself says so before its signaling has been fetched.
    enum Experience: String, Decodable {
        /// A flat picture, or several of them - a control room's multiview.
        case singleView = "single-view"
        /// A picture that wraps around the viewer: 180°, 360°.
        case immersive
        
        /// What an entry without an `experience` key can still be told as: forced-geometry
        /// content names its geometry. Anything else is only known once its signaling is in.
        init?(inferredFrom video: Video) {
            guard let geometry = video.signalingVersion?.rawValue, geometry.hasPrefix("ns_") else {
                return nil
            }
            self = geometry.contains("flat") ? .singleView : .immersive
        }
    }
    
    /// How `video` is watched, or `nil` when the list does not say and it cannot be told.
    func experience(of video: Video) -> Experience? {
        experiences[video.id]
    }
    
    /// What the list says about an entry beyond what `Video` reads.
    private struct CatalogEntry: Decodable {
        let experience: Experience?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // A value the demo does not know is no experience, not a list that fails to load.
            experience = try? container.decodeIfPresent(Experience.self, forKey: .experience)
        }
        
        private enum CodingKeys: String, CodingKey {
            case experience
        }
    }
}
