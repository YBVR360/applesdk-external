//
//  AdTestSchedule.swift
//  DemoApp
//

import Foundation
import YBVRAppleSDK

@MainActor
@Observable
final class AdTestSchedule {
    
    enum Preset: String, CaseIterable, Identifiable {
        case angelOne = "Angel One · 60s"
        case dolby = "Dolby · 98s"
        case bipbop = "BipBop · 30m"
        
        var id: String { rawValue }
        
        var urlString: String {
            return switch self {
            case .angelOne:
                "https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8"
            case .dolby:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8"
            case .bipbop:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
            }
        }
    }
    
    var creativeURLStrings: [String] = [Preset.angelOne.urlString]
    
    var draftCreativeURL: String = ""
    
    var canAddDraftCreative: Bool {
        let trimmed = draftCreativeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !creativeURLStrings.contains(trimmed)
    }
    
    func addDraftCreative() {
        guard canAddDraftCreative else { return }
        addCreative(draftCreativeURL.trimmingCharacters(in: .whitespacesAndNewlines))
        draftCreativeURL = ""
    }
    
    func addCreative(_ urlString: String) {
        guard !creativeURLStrings.contains(urlString) else { return }
        creativeURLStrings.append(urlString)
    }
    
    func removeCreative(at index: Int) {
        guard creativeURLStrings.indices.contains(index) else { return }
        creativeURLStrings.remove(at: index)
    }
    
    // MARK: Duration
    
    /// `nil` means play the creative to its natural end.
    static let durationOptions: [Double?] = [5, 15, 30, 60, nil]
    
    var maxDurationSeconds: Double? = 15
    
    // MARK: Skip
    
    /// `nil` disables the gate.
    static let skipAfterOptions: [Double?] = [nil, 5, 10, 15]
    
    var skipAfterSeconds: Double? = 5
    
    static func durationLabel(_ value: Double?) -> String {
        value.map { "\(Int($0))s" } ?? "Full"
    }
    
    static func skipLabel(_ value: Double?) -> String {
        value.map { "\(Int($0))s" } ?? "Off"
    }
    
    var preRoll = false
    var midRoll = true
    var midRollSeconds: Double = 15
    var postRoll = false
    
    var immersiveGeometry: SignalingVersion? = nil
    
    var isEmpty: Bool {
        (!preRoll && !midRoll && !postRoll) || creativeURLStrings.isEmpty
    }
    
    func breaks() -> [YBVRAdBreak] {
        let urls = creativeURLStrings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !urls.isEmpty else { return [] }
        
        let creatives = urls.map { YBVRAdCreative(urlString: $0, geometry: immersiveGeometry) }
        
        func make(_ id: String, _ cue: YBVRAdCue) -> YBVRAdBreak {
            YBVRAdBreak(id: id,
                        cue: cue,
                        creatives: creatives,
                        maxDuration: maxDurationSeconds,
                        skipAfter: skipAfterSeconds)
        }
        
        var result: [YBVRAdBreak] = []
        if preRoll {
            result.append(make("demo-pre", .preRoll))
        }
        if midRoll {
            result.append(make("demo-mid-\(Int(midRollSeconds))", .midRoll(midRollSeconds)))
        }
        if postRoll {
            result.append(make("demo-post", .postRoll))
        }
        return result
    }
}
