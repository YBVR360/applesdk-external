//
//  TimeFormat.swift
//  Shared
//
//  Created by Isaac Roldan on 25/11/2019.
//  Copyright © 2019 ybvr. All rights reserved.
//

import Foundation

// Useful formatter to show the HH:mm timestamp of the video in the video control view.
enum TimeFormat {
    private static var timeMSFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
    
    private static var timeHMSFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
    
    static func formatSecondsToHMS(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite else { return "--:--:--" }
        if seconds > 3600 {
            return timeHMSFormatter.string(from: seconds) ?? "00:00:00"
        }
        else {
            return timeMSFormatter.string(from: seconds) ?? "00:00"
        }
    }
}
