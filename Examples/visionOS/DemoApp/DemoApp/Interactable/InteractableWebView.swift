//
//  InteractableWebView.swift
//  DemoApp
//
//  Created by Peter Angiuoli on 4/21/25.
//

import SwiftUI
import WebKit
import YBVRAppleSDK

struct InteractableWebView: UIViewRepresentable {
    var interactableGraphic: InteractableGraphic

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = context.coordinator.webView
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: URL(string: interactableGraphic.url)!)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: InteractableWebView
        let webView = WKWebView()

        init(_ parent: InteractableWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        }
    }
}
