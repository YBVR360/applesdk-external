//
//  AdScheduleForm.swift
//  DemoApp
//

import SwiftUI
import YBVRAppleSDK

struct AdScheduleForm: View {
    @Bindable var schedule: AdTestSchedule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            creativeField
            presetRow
            
            HarnessDivider()
            
            cueToggles
            
            HarnessDivider()
            
            durationRow
            skipRow
            
            HarnessDivider()
            
            optionsRow
        }
    }
    
    @ViewBuilder
    var creativeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Creatives")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
                if schedule.creativeURLStrings.count > 1 {
                    Text("pod of \(schedule.creativeURLStrings.count), played in order")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            
            if schedule.creativeURLStrings.isEmpty {
                Text("No creatives - add at least one below.")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else {
                ForEach(Array(schedule.creativeURLStrings.enumerated()), id: \.offset) { index, url in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                            .foregroundStyle(.black)
                            .frame(width: 16, height: 16)
                            .background(.yellow, in: Circle())
                        
                        Text(url)
                            .font(.system(size: 11).monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer(minLength: 0)
                        
                        Button {
                            schedule.removeCreative(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            
            HStack(spacing: 8) {
                TextField("",
                          text: $schedule.draftCreativeURL,
                          prompt: Text("https://…/ad.m3u8").foregroundColor(.gray))
                .textFieldStyle(.plain)
                .font(.system(size: 12).monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .keyboardType(.URL)
                .onSubmit { schedule.addDraftCreative() }
                .padding(8)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                
                Button {
                    schedule.addDraftCreative()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(schedule.canAddDraftCreative ? .yellow : .white.opacity(0.3))
                }
                .buttonStyle(.borderless)
                .disabled(!schedule.canAddDraftCreative)
            }
        }
    }
    
    @ViewBuilder
    var presetRow: some View {
        HStack(spacing: 8) {
            Text("Add")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
            ForEach(AdTestSchedule.Preset.allCases) { preset in
                Button {
                    schedule.addCreative(preset.urlString)
                } label: {
                    Text(preset.rawValue)
                        .foregroundStyle(.white)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.15), in: .capsule)
                }
                .buttonStyle(.borderless)
                .disabled(schedule.creativeURLStrings.contains(preset.urlString))
            }
        }
    }
    
    @ViewBuilder
    var cueToggles: some View {
        let stepValue = 5.0
        VStack(alignment: .leading, spacing: 10) {
            HarnessToggle(title: "Pre-roll", isOn: $schedule.preRoll)
            
            HStack {
                HarnessToggle(title: "Mid-roll", isOn: $schedule.midRoll)
                Spacer(minLength: 0)
                Text("at \(Int(schedule.midRollSeconds))s")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                Stepper("") {
                    schedule.midRollSeconds += stepValue
                } onDecrement: {
                    schedule.midRollSeconds = max(0, schedule.midRollSeconds - stepValue)
                }
                .labelsHidden()
            }
            
            HarnessToggle(title: "Post-roll", isOn: $schedule.postRoll)
            
            Text("Post-roll holds back end-of-video until the ad finishes, so the player is not dismissed before it plays.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    @ViewBuilder
    var durationRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Ad duration")
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
                Text("caps any creative")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            HStack(spacing: 6) {
                ForEach(AdTestSchedule.durationOptions, id: \.self) { option in
                    HarnessPill(title: AdTestSchedule.durationLabel(option), isSelected: schedule.maxDurationSeconds == option) {
                        schedule.maxDurationSeconds = option
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    var skipRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Skip after")
                    .font(.system(size: 12, weight: .medium))
                if let skip = schedule.skipAfterSeconds,
                   let cap = schedule.maxDurationSeconds,
                   skip >= cap {
                    Text("longer than the ad")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
            
            HStack(spacing: 6) {
                ForEach(AdTestSchedule.skipAfterOptions, id: \.self) { option in
                    HarnessPill(title: AdTestSchedule.skipLabel(option), isSelected: schedule.skipAfterSeconds == option) {
                        schedule.skipAfterSeconds = option
                    }
                }
            }
            
            Text("The player refuses to skip before this elapses, so the countdown is enforced rather than just shown.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    @ViewBuilder
    var optionsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Geometry")
                    .font(.system(size: 12))
                Spacer(minLength: 16)
                Picker("", selection: $schedule.immersiveGeometry) {
                    Text("Flat 2D")
                        .tag(SignalingVersion?.none)
                    Text("Equirect")
                        .tag(SignalingVersion?.some(.nsEquirectangularMono))
                    Text("Equidome")
                        .tag(SignalingVersion?.some(.nsEquidomeMono))
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ScrollView {
        AdScheduleForm(schedule: .init())
    }
    .background(.black)
}
