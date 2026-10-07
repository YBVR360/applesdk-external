//
//  DemoAppApp.swift
//  DemoApp
//
//  Created by Niko Inas on 29.01.24.
//

import SwiftUI

@main
struct DemoAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var app = AppEnvironment()
    @State private var networkMonitor = NetworkMonitor()
    @State private var directPlayerVM = DirectPlayerViewModel()
    
    var body: some Scene {
        WindowGroup {
            BootstrapView()
                .environment(app)
                .environment(networkMonitor)
                .environment(directPlayerVM)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

private struct BootstrapView: View {
    @Environment(AppEnvironment.self) private var app
    
    @State private var isReady = false
    @State private var didStart = false
    
    var body: some View {
        Group {
            if isReady {
                ContentView()
            } else {
                ProgressView("Starting…")
            }
        }
        .task {
            guard !didStart else { return }
            didStart = true
            
            await app.initialize()
            isReady = true
        }
    }
}
