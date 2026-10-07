//
//  CameraMapCRView.swift
//  DemoApp
//
//  Created by Manuel Tirado on 24.09.26.
//

import SwiftUI
import YBVRAppleSDK

/**
 The control room entry that sits beside the camera map.
 
 Content only has one when its signalling lists a view point among the control room's cameras,
 which the SDK hands over as `PlayerPresentation.controlRoomViewPoint` - so for single feed
 content this draws nothing at all. Picking it plays the control room camera and brings up the
 mini screens, the same selection the map's own markers make.
 */
struct CameraMapCRView: View {
    
    @Environment(\.cameraMap) private var cameraMap
    
    /// The map is laid out at this width; its height follows the poster's aspect ratio.
    var width: CGFloat = 130
    private let cameraBtnImgSize: CGFloat = 48
    
    @State private var icons: [String: UIImage] = [:]
    
    private var presentation: PlayerPresentation? {
        cameraMap.session?.presentation
    }
    
    private var viewPoint: ViewPoint? {
#if DEBUG
        if presentation?.controlRoomViewPoint == nil,
           ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return Self.previewViewPoint
        }
#endif
        return presentation?.controlRoomViewPoint
    }
    
    private static func markerScale(of viewPoint: ViewPoint) -> CGFloat {
        guard let scale = viewPoint.scale.flatMap(Double.init), scale > 0 else {
            return 1
        }
        return CGFloat(scale)
    }
    
    let posterRatio: Double = {
        let size = UIImage(resource: .mapCRPlaceholder).size
        guard size.width > 0, size.height > 0 else {
            return 1
        }
        return size.width / size.height
    }()
    
    var body: some View {
        if let viewPoint {
            let mapSize = CGSize(width: width, height: width / posterRatio)
            
            ZStack {
                mapView
                    .frame(width: mapSize.width, height: mapSize.height)
                
                marker(for: viewPoint)
                    .task(id: viewPoint.camID) {
                        await preloadIcons(for: viewPoint)
                    }
            }
        }
    }
    
    @ViewBuilder
    private var mapView: some View {
        ZStack {
            Image(.mapBkCRPlaceholder)
                .resizable()
                .scaledToFit()
            
            Image(.mapCRPlaceholder)
                .resizable()
                .scaledToFit()
        }
    }
    
    @ViewBuilder
    private func marker(for viewPoint: ViewPoint) -> some View {
        let isSelected = cameraMap.session?.isPlaying(viewPoint) ?? false
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
    
    private func preloadIcons(for viewPoint: ViewPoint) async {
        let urls = Set([viewPoint.iconURL, viewPoint.selectedIconURL]
            .compactMap { $0 }
            .filter { !$0.isEmpty })
        
        icons = await CameraMapImage.load(urls)
    }
}

// MARK: - Previews

#Preview {
    CameraMapCRView(width: 130)
}

#if DEBUG
// TODO: - REPLACE WITH examples
extension CameraMapCRView {
    private static let previewViewPoint = YBVRAppleSDK.ViewPoint(
        name: "Control Room", sortingIndex: 0, controlRoomID: 99, camID: 99, isEnabled: true,
        iconText: nil, iconURL: nil, mobileIconURL: nil, highlightedIconURL: nil,
        selectedIconURL: nil, mobileSelectedIconURL: nil,
        position: nil, rotation: nil, scale: "1")
}
#endif
