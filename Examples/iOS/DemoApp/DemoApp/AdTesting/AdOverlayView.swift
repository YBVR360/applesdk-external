//
//  AdOverlayView.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

struct AdOverlayView: View {
    @State var vm: StreamViewModel
    
    /// Elapsed / total for the ad on screen.
    private var timeLabel: String {
        guard vm.ads.adDuration > 0 else {
            return TimeFormat.formatSecondsToHMS(vm.ads.adPosition)
        }
        return "\(TimeFormat.formatSecondsToHMS(vm.ads.adPosition)) / \(TimeFormat.formatSecondsToHMS(vm.ads.adDuration))"
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 10) {
                backButton
                
                badge
                
                Spacer(minLength: 0)
                
                skipButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 44)
            
            Spacer(minLength: 0)
            
            progressBar
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
        }
        .allowsHitTesting(true)
    }
    
    @ViewBuilder
    var backButton: some View {
        Button {
            vm.shouldDismiss = true
        } label: {
            Image(systemName: "arrow.backward.circle")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.5), in: Circle())
        }
    }
    
    @ViewBuilder
    var skipButton: some View {
        let canSkip = vm.ads.canSkipAd
        let remaining = vm.ads.skipCountdown
        
        Button {
            vm.ads.skipCurrentAd()
        } label: {
            HStack(spacing: 6) {
                if canSkip {
                    Text("Skip Ad")
                    Image(systemName: "forward.end.fill")
                } else {
                    Text("Skip in \(remaining)")
                        .monospacedDigit()
                    Image(systemName: "lock.fill")
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(canSkip ? .white : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.7), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(canSkip ? 0.35 : 0.15), lineWidth: 1))
        }
        .disabled(!canSkip)
        .animation(.easeInOut(duration: 0.15), value: canSkip)
    }
    
    @ViewBuilder
    var badge: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("AD")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.yellow, in: RoundedRectangle(cornerRadius: 4))
                
                if let podLabel = vm.ads.adPodLabel {
                    Text(podLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                Text(vm.ads.adCueLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Text(timeLabel)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
    
    @ViewBuilder
    var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.25))
                Capsule()
                    .fill(.yellow)
                    .frame(width: geo.size.width * vm.ads.adProgress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Preview
#Preview(traits: .landscapeLeft) {
    AdOverlayView(vm: .init(video: .example))
}
