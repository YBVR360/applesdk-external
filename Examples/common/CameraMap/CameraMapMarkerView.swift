//
//  CameraMapMarkerView.swift
//  DemoApp
//
//  Created by Manuel Tirado García on 24/09/2026.
//

import SwiftUI
import YBVRAppleSDK

struct CameraMapMarkerView: View {
    
    let viewPoint: ViewPoint
    let side: CGFloat
    let icon: UIImage?
    let isSelected: Bool
    let action: () -> Void
    
    private var image: Image {
        if let icon {
            return Image(uiImage: icon)
        }
        if viewPoint.controlRoomID != nil {
            return Image(isSelected ? .mapCRSelected : .mapCRDefault)
        } else {
            return Image(isSelected ? .mapCamSelected : .mapCamDefault)
        }
    }
    
    var body: some View {
        Button(action: action) {
            image
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(Double(viewPoint.rotation?.y ?? 0)))
                .frame(width: side, height: side)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .animation(.easeInOut, value: isSelected)
    }
}

#Preview {
    CameraMapMarkerView(viewPoint: .exampleViewPoint,
                        side: 140,
                        icon: nil,
                        isSelected: false) {}
}
