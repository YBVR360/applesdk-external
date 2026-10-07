//
//  AdSetupSheet.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

struct AdSetupSheet: View {
    let harness: AdHarness
    
    let video: Video
    let onPlay: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)
            
            HarnessDivider()
            
            AdScheduleEditorView(host: harness)
            
            HarnessDivider()
            
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 860, height: 560)
        .background(Color.black)
    }
    
    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "megaphone.fill")
                .foregroundStyle(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ad breaks")
                    .font(.system(size: 17, weight: .semibold))
                Text(video.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }
    
    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 14) {
            Button("Cancel", role: .cancel, action: onCancel)
            
            Spacer(minLength: 0)
            
            Text(harness.scheduledAdBreaks.isEmpty
                 ? "No ads scheduled"
                 : "\(harness.scheduledAdBreaks.count) break(s) scheduled")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.6))
            
            Button(action: onPlay) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text(harness.scheduledAdBreaks.isEmpty ? "Play without ads" : "Play")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
        }
    }
}

#Preview {
    AdSetupSheet(harness: AdHarness(),
                 video: .example,
                 onPlay: {},
                 onCancel: {})
}
