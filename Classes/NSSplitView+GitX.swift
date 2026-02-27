//
//  NSSplitView+GitX.swift
//  GitX
//
//  Converted from NSSplitView+GitX.m
//  Original by Kent Sutherland, 2017.
//

import AppKit

extension NSSplitView {

    /// Restores autosaved divider positions that were not restored automatically
    /// when Auto Layout is enabled. Without this, split views don't restore for
    /// windows that aren't reopened via state-restoration.
    ///
    /// Source: https://stackoverflow.com/q/16587058
    @objc func pb_restoreAutosavedPositions() {
        guard let name = autosaveName else { return }
        let key = "NSSplitView Subview Frames \(name)"
        guard let subviewFrames = UserDefaults.standard.array(forKey: key) as? [String] else { return }

        // The last frame is skipped — there is one fewer divider than frames.
        for (i, frameString) in subviewFrames.enumerated() {
            guard i < subviews.count else { break }

            let components = frameString.components(separatedBy: ", ")
            guard components.count >= 5 else { continue }

            let subview = subviews[i]
            let hidden  = (components[4] as NSString).boolValue
            subview.isHidden = hidden

            if !isVertical {
                let height = CGFloat((components[3] as NSString).floatValue)
                subview.setFrameSize(NSSize(width: subview.frame.width, height: height))
            } else {
                let width = CGFloat((components[2] as NSString).floatValue)
                subview.setFrameSize(NSSize(width: width, height: subview.frame.height))
            }
        }
    }
}

