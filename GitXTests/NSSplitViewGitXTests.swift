//
//  NSSplitViewGitXTests.swift
//  GitXTests
//
//  Tests for NSSplitView+GitX (converted from ObjC).
//

import XCTest
@testable import GitX

final class NSSplitViewGitXTests: XCTestCase {

    // MARK: - pb_restoreAutosavedPositions

    func testNoopWhenNoAutosaveName() {
        let splitView = NSSplitView()
        // autosaveName is nil by default — must not crash
        XCTAssertNoThrow(splitView.pb_restoreAutosavedPositions())
    }

    func testNoopWhenNoSavedData() {
        let splitView = NSSplitView()
        splitView.autosaveName = "GitXTests.NSSplitView.NoSavedData"
        // Nothing stored in UserDefaults → must not crash, subviews unchanged
        let sub1 = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 200))
        let sub2 = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 200))
        splitView.addSubview(sub1)
        splitView.addSubview(sub2)
        XCTAssertNoThrow(splitView.pb_restoreAutosavedPositions())
        // frames must be unchanged
        XCTAssertEqual(sub1.frame.height, 200, accuracy: 1)
        XCTAssertEqual(sub2.frame.height, 200, accuracy: 1)
    }

    func testRestoresHorizontalSubviewHeights() {
        let splitView = makeSplitView(vertical: false)
        let key = "NSSplitView Subview Frames \(splitView.autosaveName!)"

        // Persist two frame strings — the format used by NSSplitView autosave
        // "{x, y, w, h, hidden}" — we only care about index 3 (height) and 4 (hidden)
        let frames = [
            "0, 0, 200, 120, 0",   // height 120, visible
            "0, 0, 200,  80, 0",   // height  80, visible
        ]
        UserDefaults.standard.set(frames, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        splitView.pb_restoreAutosavedPositions()

        XCTAssertEqual(splitView.subviews[0].frame.height, 120, accuracy: 1)
        XCTAssertEqual(splitView.subviews[1].frame.height,  80, accuracy: 1)
        XCTAssertFalse(splitView.subviews[0].isHidden)
        XCTAssertFalse(splitView.subviews[1].isHidden)
    }

    func testRestoresVerticalSubviewWidths() {
        let splitView = makeSplitView(vertical: true)
        let key = "NSSplitView Subview Frames \(splitView.autosaveName!)"

        let frames = [
            "0, 0, 150, 400, 0",
            "0, 0, 250, 400, 0",
        ]
        UserDefaults.standard.set(frames, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        splitView.pb_restoreAutosavedPositions()

        XCTAssertEqual(splitView.subviews[0].frame.width, 150, accuracy: 1)
        XCTAssertEqual(splitView.subviews[1].frame.width, 250, accuracy: 1)
    }

    func testRestoresHiddenState() {
        let splitView = makeSplitView(vertical: false)
        let key = "NSSplitView Subview Frames \(splitView.autosaveName!)"

        let frames = [
            "0, 0, 200, 100, 1",  // hidden
            "0, 0, 200, 300, 0",  // visible
        ]
        UserDefaults.standard.set(frames, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        splitView.pb_restoreAutosavedPositions()

        XCTAssertTrue(splitView.subviews[0].isHidden)
        XCTAssertFalse(splitView.subviews[1].isHidden)
    }

    func testHandlesMoreFramesThanSubviews() {
        let splitView = makeSplitView(vertical: false, subviewCount: 1)
        let key = "NSSplitView Subview Frames \(splitView.autosaveName!)"

        // 3 saved frames but only 1 subview — must not crash
        let frames = [
            "0, 0, 200, 50, 0",
            "0, 0, 200, 60, 0",
            "0, 0, 200, 70, 0",
        ]
        UserDefaults.standard.set(frames, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        XCTAssertNoThrow(splitView.pb_restoreAutosavedPositions())
        XCTAssertEqual(splitView.subviews[0].frame.height, 50, accuracy: 1)
    }

    // MARK: - Helpers

    private func makeSplitView(vertical: Bool, subviewCount: Int = 2) -> NSSplitView {
        let splitView = NSSplitView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        splitView.isVertical = vertical
        splitView.autosaveName = "GitXTests.NSSplitView.\(vertical ? "V" : "H").\(UUID().uuidString)"
        for _ in 0..<subviewCount {
            splitView.addSubview(NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200)))
        }
        return splitView
    }
}

