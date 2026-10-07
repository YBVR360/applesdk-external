//
//  AdScheduleEditorView.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

/// The scheduled-breaks list next to the break builder.
struct AdScheduleEditorView<Host: AdHarnessHosting>: View {
    let host: Host
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            scheduledList
                .frame(width: 240)
            
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AdScheduleForm(schedule: host.adTestSchedule)
                    
                    HarnessDivider()
                    
                    catchUpRow
                    
                    actionRow
                }
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(.white)
    }
    
    // MARK: - Scheduled list
    
    @ViewBuilder
    private var scheduledList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scheduled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
                if !host.scheduledAdBreaks.isEmpty {
                    Text("\(host.scheduledAdBreaks.count)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            if host.scheduledAdBreaks.isEmpty {
                Text("Nothing scheduled yet. Build a break on the right and add it - applying again appends, so you can mix cues, caps and creatives.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(host.scheduledAdBreaks) { adBreak in
                            row(for: adBreak)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
    }
    
    @ViewBuilder
    private func row(for adBreak: YBVRAdBreak) -> some View {
        let isOnScreen = host.adPlayback?.adBreak.id == adBreak.id
        let hasPlayed = host.playedAdBreakIds.contains(adBreak.id)
        
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOnScreen ? .yellow : (hasPlayed ? .white.opacity(0.25) : .yellow.opacity(0.6)))
                    .frame(width: 7, height: 7)
                
                Text(adBreak.cue.displayLabel)
                    .font(.system(size: 11, weight: .semibold))
                
                Spacer(minLength: 0)
                
                if isOnScreen {
                    Text("on screen")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.yellow)
                } else if hasPlayed {
                    Text("played")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Button {
                    host.removeScheduledBreak(id: adBreak.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            
            Text(detailLabel(for: adBreak))
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(hasPlayed ? 0.04 : 0.09), in: RoundedRectangle(cornerRadius: 6))
        .opacity(hasPlayed ? 0.65 : 1)
    }
    
    private func detailLabel(for adBreak: YBVRAdBreak) -> String {
        [adBreak.creatives.count == 1 ? "1 creative" : "\(adBreak.creatives.count) creatives",
         adBreak.maxDuration.map { "\(Int($0))s cap" } ?? "full length",
         adBreak.skipAfter.map { "skip @ \(Int($0))s" } ?? "skippable"]
            .joined(separator: " · ")
    }
    
    // MARK: - Rows
    
    @ViewBuilder
    private var catchUpRow: some View {
        let catchUp = Binding(get: { host.playsMissedMidRollsOnSeek },
                              set: { host.playsMissedMidRollsOnSeek = $0 })
        
        VStack(alignment: .leading, spacing: 6) {
            HarnessToggle(title: "Catch up on seek", isOn: catchUp)
            
            Text(catchUp.wrappedValue
                 ? "Scrubbing past a cue plays the ad for the segment you land in. Going back to an unseen segment plays its ad."
                 : "Cues only fire while playing through them. Scrubbing past one misses that ad for good.")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    @ViewBuilder
    private var actionRow: some View {
        let canApply = !host.adTestSchedule.isEmpty
        
        HStack(spacing: 10) {
            Button {
                host.applyAdTestSchedule()
            } label: {
                Text(host.scheduledAdBreaks.isEmpty ? "Apply schedule" : "Add to schedule")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(canApply ? .black : .white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(canApply ? .yellow : .gray.opacity(0.4), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(!canApply)
            
            Button {
                host.clearAdBreaks()
            } label: {
                Text("Clear")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(host.scheduledAdBreaks.isEmpty)
        }
    }
}

#Preview {
    VStack {
        AdScheduleEditorView(host: AdHarness())
    }
    .background(.black)
}
