//
//  YBVRAdCue+Label.swift
//  DemoApp
//

import Foundation
import YBVRAppleSDK

extension YBVRAdCue {
    
    var displayLabel: String {
        switch self {
        case .preRoll:            return "Pre-roll"
        case .midRoll(let secs):  return "Mid-roll · \(Int(secs))s"
        case .postRoll:           return "Post-roll"
        }
    }
}
