//
//  CameraMapView.swift
//  DemoApp
//
//  Created by Manuel Tirado García on 24/09/2026.
//

import SwiftUI

/// Both camera maps side by side: the immersive views, and the control room's multiview when the
/// content has one. Reads its host through `cameraMap(session:select:)`.
struct CameraMapView: View {
    @Environment(\.cameraMap) private var cameraMap
    
    private var hasImmView: Bool {
        guard let session = cameraMap.session else { return true }
        return session.presentation?.allViewPoints.count ?? 0 > 1
    }
    private var hasControlRoom: Bool {
        guard let session = cameraMap.session else { return true }
        return session.presentation?.controlRoomViewPoint != nil
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            if hasImmView {
                VStack(spacing: 0) {
                    CameraMapImmView(width: 280)
                    Text("IMMERSIVE VIEWS")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.gray)
                        .frame(height: 40)
                }
            }
            if hasControlRoom {
                VStack(spacing: 0) {
                    CameraMapCRView(width: 130)
                    Text("MULTIVIEW")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.gray)
                        .frame(height: 40)
                }
            }
        }
        .padding([.top, .horizontal], 20)
        .background(Color(red: 0.13, green: 0.13, blue: 0.13), in: RoundedRectangle(cornerRadius: 32))
    }
}

#Preview {
    CameraMapView()
}

/**
 The camera map, shrunk to fit the space it is offered - for a host with less room than the
 map's own size, as on an iPhone between the header and the transport bar.
 
 Laid out at its natural size and scaled down as a whole, so the markers keep their places on
 the poster; never scaled up past it. Sits at the bottom of the space, against the toolbar
 that opens it. Reads its host through `cameraMap(session:select:)`, as `CameraMapView` does.
 */
struct FittedCameraMapView: View {
    
    /// The map's size before any scaling, measured as it lays out - it changes as the poster
    /// loads, and with whether the content has a multiview.
    @State private var naturalSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            CameraMapView()
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { naturalSize = $0 }
                .scaleEffect(Self.scale(fitting: naturalSize, in: geometry.size), anchor: .bottom)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }
    }
    
    /// The largest scale, up to 1, at which `size` fits inside `space`.
    static func scale(fitting size: CGSize, in space: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return max(0, min(1, space.width / size.width, space.height / size.height))
    }
}
