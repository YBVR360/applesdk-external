//
//  CameraMapImmView.swift
//  Shared
//
//  Created by Manuel Tirado García on 24/09/2026.
//

import SwiftUI
import YBVRAppleSDK

/**
 The camera map, flat.
 
 Keeps the placement rules of the immersive map - normalised view point positions, per point
 scale, the pin turned to the direction its camera faces - but draws them with plain SwiftUI,
 so the map sits in an ordinary window next to the player controls.
 
 Picking a marker goes through the host's `CameraMapContext.select` - which ends in the SDK's
 `didSelectCamera(from:)` - and what is drawn as selected is read back off the player through
 `PlaybackSession.isPlaying(_:)`, so the map and the camera list agree on what is playing -
 including on first entry, before anything has been picked by hand.
 */
struct CameraMapImmView: View {
    
    @Environment(\.cameraMap) private var cameraMap
    
    /// The map is laid out at this width; its height follows the poster's aspect ratio.
    let width: CGFloat
    let applyMarkerInset: Bool
    
    @State private var mapImage: UIImage?
    @State private var mapBackgroundImage: UIImage?
    /// Marker icons, keyed by the URL string they were loaded from.
    @State private var icons: [String: UIImage] = [:]
    @State private var posterRatio: Double = CameraMapImmView.placeholderRatio
    
    private let cameraBtnImgSize: CGFloat = 48
    
    /// The proportions the map is laid out at until its own poster has loaded.
    private static let placeholderRatio: Double = {
        let size = UIImage(resource: .mapPlaceholder).size
        guard size.width > 0, size.height > 0 else {
            return 830.0 / 400.0
        }
        return size.width / size.height
    }()
    
    private var presentation: PlayerPresentation? {
        cameraMap.session?.presentation
    }
    
    /// Everything `preloadImgs()` fetches. Keyed on the poster alone, a content switch that
    /// kept the same poster - or had none either side - left the background and the markers'
    /// icons showing the title before it.
    private var artworkKey: String {
        guard let presentation else {
            return ""
        }
        
        let urls = [presentation.iccImageURL?.absoluteString,
                    presentation.iccBackgroundImageURL?.absoluteString]
        + presentation.allViewPoints.flatMap { [$0.iconURL, $0.selectedIconURL] }
        
        return urls.compactMap { $0 }.joined(separator: "|")
    }
    
    private var viewPoints: [ViewPoint] {
        let viewPoints = (presentation?.cameraViewPoints ?? [])
            .filter { $0.camID != nil }
#if DEBUG
        if viewPoints.isEmpty, ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return ViewPoint.exampleCameraMap
        }
#endif
        return viewPoints
    }
    
    init(width: CGFloat, applyMarkerInset: Bool = false) {
        self.width = width
        self.applyMarkerInset = applyMarkerInset
    }
    
    var body: some View {
        content
            .task(id: artworkKey) {
                await preloadImgs()
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewPoints.isEmpty {
            EmptyView()
        } else {
            let mapSize = CGSize(width: width, height: width / posterRatio)
            let inset = markerInset
            
            ZStack {
                mapView
                    .frame(width: mapSize.width, height: mapSize.height)
                
                markers(in: mapSize, inset: inset)
            }
            .frame(width: mapSize.width + inset * 2, height: mapSize.height + inset * 2)
        }
    }
    
    // MARK: - Map
    
    @ViewBuilder
    private var mapView: some View {
        ZStack {
            if let mapBackgroundImage {
                Image(uiImage: mapBackgroundImage)
                    .resizable()
                    .scaledToFill()
            } else if mapImage == nil {
                Image(uiImage: .mapBkPlaceholder)
                    .resizable()
                    .scaledToFill()
            }
            
            if let mapImage {
                Image(uiImage: mapImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(.mapPlaceholder)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
    
    // MARK: - Markers
    
    @ViewBuilder
    private func markers(in mapSize: CGSize, inset: CGFloat) -> some View {
        ForEach(viewPoints, id: \.camID) { viewPoint in
            if let position = viewPoint.position {
                marker(for: viewPoint)
                // `position` is normalised to the map: x across it, z up from its centre,
                // and the map itself starts `inset` into the box being placed in.
                    .position(x: inset + (0.5 + CGFloat(position.x)) * mapSize.width,
                              y: inset + (0.5 - CGFloat(position.z)) * mapSize.height)
            }
        }
    }
    
    @ViewBuilder
    private func marker(for viewPoint: ViewPoint) -> some View {
        let isSelected = cameraMap.session?.isPlaying(viewPoint) ?? false
        // Content that signals one icon per camera keeps it when selected, rather than
        // dropping back to the demo's own pin.
        let iconKey = (isSelected ? (viewPoint.selectedIconURL ?? viewPoint.iconURL)
                       : viewPoint.iconURL) ?? ""
        
        CameraMapMarkerView(viewPoint: viewPoint,
                            side: cameraBtnImgSize * Self.markerScale(of: viewPoint),
                            icon: icons[iconKey],
                            isSelected: isSelected) {
            Task {
                await cameraMap.select(viewPoint)
            }
        }
    }
}

// MARK: - Logic
extension CameraMapImmView {
    
    // MARK: - Marker metrics
    
    private static func markerScale(of viewPoint: ViewPoint) -> CGFloat {
        guard let scale = viewPoint.scale.flatMap(Double.init), scale > 0 else {
            return 1
        }
        return CGFloat(scale)
    }
    
    /// How far the widest marker reaches past its own anchor, once turned and scaled.
    private var markerInset: CGFloat {
        var inset: CGFloat = 0
        guard applyMarkerInset else { return inset}
        
        for viewPoint in viewPoints {
            let side = cameraBtnImgSize * Self.markerScale(of: viewPoint)
            let angle = Angle.degrees(Double(viewPoint.rotation?.y ?? 0)).radians
            
            inset = max(inset, side / 2 * (abs(cos(angle)) + abs(sin(angle))))
        }
        
        return inset
    }
    
    // MARK: - Image preloading
    
    private func preloadImgs() async {
        guard let presentation else {
            return
        }
        
        async let map = CameraMapImage.load(presentation.iccImageURL)
        async let mapBackground = CameraMapImage.load(presentation.iccBackgroundImageURL)
        
        let iconUrls = Set(presentation.allViewPoints
            .flatMap { [$0.iconURL, $0.selectedIconURL] }
            .compactMap { $0 }
            .filter { !$0.isEmpty })
        
        let loadedIcons = await CameraMapImage.load(iconUrls)
        
        let mapImage = await map
        
        // Derive the aspect ratio from the poster itself; the placeholder's until then.
        if let size = mapImage?.size, size.width > 0, size.height > 0 {
            posterRatio = size.width / size.height
        } else {
            posterRatio = Self.placeholderRatio
        }
        
        self.mapImage = mapImage
        self.mapBackgroundImage = await mapBackground
        self.icons = loadedIcons
    }
}

// MARK: - Previews

#Preview {
    CameraMapImmView(width: 600)
}
