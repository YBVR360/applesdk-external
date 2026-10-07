//
//  OverlayVisibility.swift
//  DemoApp
//
//  Shared by the iOS and visionOS demo apps.
//

import SwiftUI

/// Shows the player controls and hides them again after an idle spell.
@MainActor
@Observable
final class OverlayVisibility {
    
    /// Whether the controls are on screen.
    private(set) var isVisible = false
    
    var autoHideInterval: TimeInterval
    
    /// While pinned the controls never auto-hide - an ad on screen, or an open panel that
    /// would be orphaned by the controls going away. Interaction still re-arms the timer.
    var isPinned: Bool { !pinReasons.isEmpty }
    
    /// Several things hold the controls open at once and none of them knows about the others,
    /// so each holds by name and the controls stay up until the last one lets go.
    private var pinReasons: Set<String> = []
    
    /// Holds the controls open, or lets go, on behalf of `reason`.
    func setPinned(_ pinned: Bool, reason: String) {
        let changed = pinned
        ? pinReasons.insert(reason).inserted
        : pinReasons.remove(reason) != nil
        
        guard changed, !isPinned, isVisible else { return }
        armTimer()
    }
    
    func holdForScrub(_ isScrubbing: Bool) {
        setPinned(isScrubbing, reason: "scrub")
    }

    /// Asked before hiding. Returning `false` keeps the controls up and stops the timer -
    /// the demos use it so a paused video keeps its controls.
    var canAutoHide: () -> Bool = { true }

    /// Asked before showing. Returning `false` keeps the controls down
    var canShow: () -> Bool = { true }
    
    private var hideTask: Task<Void, Never>?
    
    init(autoHideInterval: TimeInterval = 5) {
        self.autoHideInterval = autoHideInterval
    }
    
    /// Reveals the controls and restarts the countdown. The call to make from anything the
    /// viewer does - a tap, a pinch, a button.
    func show() {
        guard canShow() else { return }
        if !isVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                isVisible = true
            }
        }
        armTimer()
    }
    
    func hide() {
        hideTask?.cancel()
        hideTask = nil
        
        guard isVisible else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isVisible = false
        }
    }
    
    func toggle() {
        if isVisible { hide() } else { show() }
    }
    
    /// Hides the controls and forgets any pending countdown, without animating. For teardown,
    /// where the view is going away anyway.
    func reset() {
        hideTask?.cancel()
        hideTask = nil
        isVisible = false
        pinReasons.removeAll()
    }
    
    private func armTimer() {
        hideTask?.cancel()
        
        let interval = autoHideInterval
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            
            guard !Task.isCancelled, let self, self.isVisible else { return }
            guard !self.isPinned, self.canAutoHide() else { return }
            
            self.hide()
        }
    }
}
