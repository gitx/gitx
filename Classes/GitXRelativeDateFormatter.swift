//
//  GitXRelativeDateFormatter.swift
//  GitX
//
//  Converted from GitXRelativeDateFormatter.m
//  Original by Nathan Kinsinger, Copyright 2010.
//

import Foundation

private let minute: TimeInterval = 60
private let hour: TimeInterval   = 60 * minute
private let week: Int            = 7

@objc(GitXRelativeDateFormatter)
final class GitXRelativeDateFormatter: Formatter {

    override func string(for obj: Any?) -> String? {
        guard let date = obj as? Date else { return nil }

        let now = Date()
        let secondsAgo = now.timeIntervalSince(date)

        if secondsAgo < 0            { return "In the future!" }
        if secondsAgo < minute       { return "seconds ago" }
        if secondsAgo < 2 * minute   { return "1 minute ago" }
        if secondsAgo < hour         { return "\(Int(secondsAgo / minute)) minutes ago" }
        if secondsAgo < 2 * hour     { return "1 hour ago" }

        // Determine calendar-day distance (not just 24-h distance)
        let cal = Calendar.current
        let startOfDate  = cal.startOfDay(for: date)
        let startOfToday = cal.startOfDay(for: now)

        let components = cal.dateComponents([.year, .month, .day],
                                            from: startOfDate,
                                            to:   startOfToday)
        let yearsAgo  = components.year  ?? 0
        let monthsAgo = components.month ?? 0
        let daysAgo   = components.day   ?? 0

        if yearsAgo == 0 {
            if monthsAgo == 0 {
                // Still today, or less than 6 hours ago → show hours
                if daysAgo == 0 || secondsAgo < 6 * hour {
                    return "\(Int(secondsAgo / hour)) hours ago"
                }
                if daysAgo == 1 { return "Yesterday" }
                if daysAgo >= 2 * week {
                    return "\(daysAgo / week) weeks ago"
                }
                return "\(daysAgo) days ago"
            }
            if monthsAgo == 1 { return "1 month ago" }
            return "\(monthsAgo) months ago"
        }

        if yearsAgo == 1 {
            if monthsAgo == 0 { return "1 year ago" }
            if monthsAgo == 1 { return "1 year 1 month ago" }
            return "1 year \(monthsAgo) months ago"
        }

        return "\(yearsAgo) years ago"
    }
}

