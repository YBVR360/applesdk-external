//
//  SampleSceneApp.swift
//  SampleScene
//

import SwiftUI

@main
struct SampleSceneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var app = AppEnvironment()
    @State private var networkMonitor = NetworkMonitor()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(networkMonitor)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all
    
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

/// Fetches the app configuration once, then shows the video list.
private struct RootView: View {
    @Environment(AppEnvironment.self) private var app
    
    var body: some View {
        Group {
            if app.isReady {
                NavigationStack {
                    VideoListView()
                }
            } else {
                ProgressView("Starting…")
            }
        }
        .task {
            guard !app.isReady else { return }
            // Your YBVR app name: it picks the configuration and analytics for your account.
            await app.initialize(appName: "yeap")
        }
    }
}
