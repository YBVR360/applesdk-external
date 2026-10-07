//
//  AdSchedulePanel.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

/// The ad-break scheduler, as an overlay panel over the player.
struct AdSchedulePanel: View {
    @State var vm: StreamViewModel
    var onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(12)
            
            HarnessDivider()
            
            AdScheduleEditorView(host: vm.ads)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15)))
        .foregroundStyle(.white)
        .padding(.vertical)
    }
    
    @ViewBuilder
    private var header: some View {
        HStack {
            Image(systemName: "megaphone.fill")
            Text("Ad breaks")
                .font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(6)
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    AdSchedulePanel(vm: .init(video: .example)) { }
}
