//
//  AdPlaybackBar.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

/**
 What the player controls show while an ad break is on screen.
 
 The ad renders in the immersive space like the content does, so there is no 2D plane to
 overlay a badge onto - the controls window carries it instead, in place of the transport row.
 Seeking and camera changes are meaningless during a break, so nothing here offers them.
 */
struct AdPlaybackBar: View {
    let harness: AdHarness
    
    var onBack: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            if let onBack {
                PlayerControlButton(icon: "arrow.backward", action: onBack)
            }
            badge
            progressBar
            timeLabel
            skipButton
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var badge: some View {
        HStack(spacing: 8) {
            Text("AD")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.yellow, in: RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 1) {
                if let podLabel = harness.adPodLabel {
                    Text(podLabel)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(harness.adCueLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize()
    }
    
    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(.yellow)
                    .frame(width: geo.size.width * harness.adProgress)
            }
        }
        .frame(height: 6)
    }
    
    @ViewBuilder
    private var timeLabel: some View {
        Text(timeText)
            .font(.callout.monospacedDigit())
            .foregroundStyle(.white)
            .fixedSize()
    }
    
    @ViewBuilder
    private var skipButton: some View {
        Button {
            harness.skipCurrentAd()
        } label: {
            HStack(spacing: 6) {
                if harness.canSkipAd {
                    Text("Skip Ad")
                    Image(systemName: "forward.end.fill")
                } else {
                    Text("Skip in \(harness.skipCountdown)")
                        .monospacedDigit()
                    Image(systemName: "lock.fill")
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .fixedSize()
        }
        .disabled(!harness.canSkipAd)
        .animation(.easeInOut(duration: 0.15), value: harness.canSkipAd)
    }
    
    /// Elapsed / total for the ad on screen.
    private var timeText: String {
        guard harness.adDuration > 0 else {
            return TimeFormat.formatSecondsToHMS(harness.adPosition)
        }
        return "\(TimeFormat.formatSecondsToHMS(harness.adPosition)) / \(TimeFormat.formatSecondsToHMS(harness.adDuration))"
    }
}

#Preview {
    AdPlaybackBar(harness: AdHarness())
        .frame(width: 658)
        .glassBackgroundEffect()
}
