//
//  HarnessControls.swift
//  DemoApp
//

import SwiftUI

/// Hairline between sections of a harness panel.
struct HarnessDivider: View {
    var body: some View {
        Divider().overlay(.white.opacity(0.6))
    }
}

/// Switch row used throughout the harness.
struct HarnessToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title).font(.system(size: 12))
        }
        .toggleStyle(.switch)
        .foregroundStyle(.white)
        .tint(.yellow)
        .fixedSize()
    }
}

/// Selectable capsule, used for the option rows.
struct HarnessPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(minWidth: 38)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? Color.yellow : Color.white.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.borderless)
    }
}

#Preview {
    @Previewable @State var isToggleOn: Bool = false
    @Previewable @State var isPillOn: Bool = false
    
    VStack {
        HarnessToggle(title: "title", isOn: $isToggleOn)
        HarnessDivider()
        HarnessPill(title: "title", isSelected: isPillOn) {
            isPillOn.toggle()
        }
    }
    .padding()
    .background(.black)
}
