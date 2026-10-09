//
//  Notifications.swift
//  Shared
//
//  The video player's notifications, as the Master Notification Inventory words them.
//

import SwiftUI
import YBVRAppleSDK

// MARK: - Copy

/// Every video player notification's text, in one place.
enum PlayerNotifications {
    
    // Anchored, low and medium attention: shown above the controls.
    
    /// The viewer picked another camera - control room feed or immersive view point.
    static let changingView = "Changing view…"
    /// The camera picked is now the one playing.
    static let cameraChanged = "Camera Changed"
    
    // Modal, high attention: block until acknowledged.
    
    /// A blocking notification: a title, a message and the button that dismisses it.
    struct Modal: Equatable {
        let title: String
        let message: String
        var button = "GOT IT!"
    }
    
    /// The video could not be played - no URL, no signaling, a playback error.
    static let somethingWentWrong = Modal(title: "OOPS!",
                                          message: "Something went wrong. Please try again later.")
    /// There is no network connection.
    static let connectionLost = Modal(title: "OOOPS!",
                                      message: "Unable to connect, contact your server.")
}

extension View {
    /// Presents `modal` as a blocking alert, and clears it once acknowledged.
    func playerModal(_ modal: Binding<PlayerNotifications.Modal?>) -> some View {
        alert(modal.wrappedValue?.title ?? "",
              isPresented: Binding(get: { modal.wrappedValue != nil },
                                   set: { if !$0 { modal.wrappedValue = nil } }),
              presenting: modal.wrappedValue) { modal in
            Button(modal.button, role: .cancel) { }
        } message: { modal in
            Text(modal.message)
        }
    }
}

// MARK: - Anchored notices

/// The notice anchored above the playback controls: one at a time, coloured by what it conveys.
@MainActor
@Observable
final class PlayerNotice {
    
    enum Status {
        case informational
        case success
        case warning
        
        var color: Color {
            switch self {
            case .informational: .blue
            case .success: .green
            case .warning: .yellow
            }
        }
    }
    
    struct Message: Hashable {
        let text: String
        let status: Status
    }
    
    private(set) var message: Message?
    
    @ObservationIgnored private var clearTask: Task<Void, Never>?
    
    /// Shows `text`, replacing whatever was on screen. `dismissAfter: nil` keeps it up until
    /// `dismiss(_:)` or another notice replaces it.
    func post(_ text: String, status: Status, dismissAfter: Duration? = .seconds(2.5)) {
        message = Message(text: text, status: status)
        clearTask?.cancel()
        guard let dismissAfter else { return }
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: dismissAfter)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
    
    /// Takes `text` down, if it is still the one on screen.
    func dismiss(_ text: String) {
        guard message?.text == text else { return }
        clearTask?.cancel()
        message = nil
    }
    
    // MARK: Camera changes
    
    func cameraChangeBegan() {
        post(PlayerNotifications.changingView, status: .informational, dismissAfter: nil)
    }
    
    func cameraChangeEnded() {
        post(PlayerNotifications.cameraChanged, status: .success)
    }
    
    func reset() {
        clearTask?.cancel()
        message = nil
    }
}

/// The anchored notice: a status dot and the text.
struct PlayerNoticeBanner: View {
    let notice: PlayerNotice
    
    var body: some View {
        if let message = notice.message {
            HStack(spacing: 8) {
                Circle()
                    .fill(message.status.color)
                    .frame(width: 8, height: 8)
                Text(message.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 0.13, green: 0.13, blue: 0.13), in: Capsule())
            .frame(maxWidth: 520)
            .transition(.opacity)
            .id(message)
            .allowsHitTesting(false)
        }
    }
}
