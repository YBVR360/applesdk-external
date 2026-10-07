//
//  InteractableView.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK
import MediaPlayer

struct InteractableView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerCoordinator.self) private var coordinator
    
    let interactableGraphic: InteractableGraphic
    
    var body: some View {
        VStack {
            topLayout()
            
            Spacer()
            
            mainLayout()
        }
        .frame(minWidth: 600, maxWidth: 600, minHeight: 800, maxHeight: 800 )
        .glassBackgroundEffect()
        .onTapGesture {
        }
        .onAppear {
        }
        .onDisappear {
        }
        .onChange(of: coordinator.dismissAllInteractableViews) { _, newValue in
            if newValue {
                interactableDismissed()
            }
        }
    }
    
    @MainActor @ViewBuilder
    private func mainLayout() -> some View {
        InteractableWebView(interactableGraphic: interactableGraphic)
            .onAppear {
            }
            .edgesIgnoringSafeArea(.all)
    }
    
    // Top layout
    @MainActor @ViewBuilder
    private func topLayout() -> some View {
        HStack {
            Button {
                interactableDismissed()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 19))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .frame(width: 44, height: 44)
            .padding(.horizontal, 15)
            
            Spacer()
        }
        .frame(width: 600, height: 46)
        .padding(.top, 18)
        .padding(.horizontal, 10)
    }
    
    private func interactableDismissed(){
        dismiss()
    }
}
