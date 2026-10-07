//
//  CameraMapToolbar.swift
//  DemoApp
//
//  Shared by the iOS and visionOS demo apps.
//

import SwiftUI

/**
 The pill above the transport bar: the button that opens the camera map, and beside it whatever
 else acts on the camera - recentring it, on iOS.
 
 Each button is a capsule of its own, drawn lit while its state is on - the map open, say -
 and the pill carries them on the player's glass.
 */
struct CameraMapToolbar: View {
    
    /// A button beside the camera map one.
    struct Action {
        let title: String
        let icon: String
        var isSelected: Bool = false
        let perform: () -> Void
    }
    
    /// Whether the map is open, or `nil` for content with no map to open - the pill then
    /// carries only `actions`.
    var isMapOpen: Binding<Bool>?
    var actions: [Action] = []
    
    /// Called on any press, before the button's own action - so it also keeps the controls up.
    var onInteract: () -> Void = { }
    
    var body: some View {
        HStack(spacing: 8) {
            if let isMapOpen {
                pill(title: "Camera Map", icon: "mappin.and.ellipse", isSelected: isMapOpen.wrappedValue) {
                    isMapOpen.wrappedValue.toggle()
                }
            }
            
            ForEach(actions.indices, id: \.self) { index in
                let action = actions[index]
                pill(title: action.title, icon: action.icon, isSelected: action.isSelected,
                     perform: action.perform)
            }
        }
        .padding(8)
        .playerGlass(in: Capsule())
    }
    
    @ViewBuilder
    private func pill(title: String,
                      icon: String,
                      isSelected: Bool,
                      perform: @escaping () -> Void) -> some View {
        Button {
            onInteract()
            perform()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .strokeBorder((isSelected ? Color.white : Color.black).opacity(0.4), lineWidth: 1)
                    .fill(isSelected ? .white.opacity(0.2) : .clear)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.capsule)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    @Previewable @State var isMapOpen = false
    
    CameraMapToolbar(isMapOpen: $isMapOpen,
                     actions: [.init(title: "Recenter", icon: "scope", perform: {})])
    .padding()
    .background(.gray)
}
