//
//  GitXRelativeDateFormatterTests.swift
//  GitXTests
//
//  Tests for GitXRelativeDateFormatter (converted from ObjC).
//

import XCTest
@testable import GitX

final class GitXRelativeDateFormatterTests: XCTestCase {

    private let formatter = GitXRelativeDateFormatter()

    // MARK: - Helpers

    private func string(secondsAgo: TimeInterval) -> String? {
        formatter.string(for: Date(timeIntervalSinceNow: -secondsAgo))
    }

    private func string(daysAgo: Int) -> String? {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
        return formatter.string(for: date)
    }

    private func string(monthsAgo: Int) -> String? {
        let cal = Calendar.current
        let date = cal.date(byAdding: .month, value: -monthsAgo, to: cal.startOfDay(for: Date()))!
        return formatter.string(for: date)
    }

    private func string(yearsAgo: Int, extraMonths: Int = 0) -> String? {
        var comps = DateComponents()
        comps.year  = -yearsAgo
        comps.month = -extraMonths
        let date = Calendar.current.date(byAdding: comps, to: Calendar.current.startOfDay(for: Date()))!
        return formatter.string(for: date)
    }

    // MARK: - Non-date input

    func testNilForNonDate() {
        XCTAssertNil(formatter.string(for: "not a date"))
        XCTAssertNil(formatter.string(for: nil))
        XCTAssertNil(formatter.string(for: 42))
    }

    // MARK: - Future date

    func testFutureDate() {
        let future = Date(timeIntervalSinceNow: 60)
        XCTAssertEqual(formatter.string(for: future), "In the future!")
    }

    // MARK: - Seconds / minutes / hours

    func testSecondsAgo() {
        XCTAssertEqual(string(secondsAgo: 0),  "seconds ago")
        XCTAssertEqual(string(secondsAgo: 30), "seconds ago")
        XCTAssertEqual(string(secondsAgo: 59), "seconds ago")
    }

    func testOneMinuteAgo() {
        XCTAssertEqual(string(secondsAgo: 60),  "1 minute ago")
        XCTAssertEqual(string(secondsAgo: 119), "1 minute ago")
    }

    func testMinutesAgo() {
        XCTAssertEqual(string(secondsAgo: 120),  "2 minutes ago")
        XCTAssertEqual(string(secondsAgo: 3599), "59 minutes ago")
    }

    func testOneHourAgo() {
        XCTAssertEqual(string(secondsAgo: 3600), "1 hour ago")
        XCTAssertEqual(string(secondsAgo: 7199), "1 hour ago")
    }

    // MARK: - Hours (same calendar day or < 6 h)

    func testHoursAgoSameDay() {
        // 2 hours ago — still today and < 6 h → "X hours ago"
        XCTAssertEqual(string(secondsAgo: 7200), "2 hours ago")
    }

    // MARK: - Days

    func testYesterday() {
        // The formatter returns "Yesterday" only when daysAgo == 1 AND secondsAgo >= 6 h.
        // Simulate by creating a date that is exactly 1 calendar day before today at midnight.
        let cal = Calendar.current
        let yesterdayMidnight = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        // Subtract an extra 7 hours to ensure secondsAgo > 6*3600
        let date = yesterdayMidnight.addingTimeInterval(-7 * 3600)
        XCTAssertEqual(formatter.string(for: date), "Yesterday")
    }

    func testDaysAgo() {
        XCTAssertEqual(string(daysAgo: 3),  "3 days ago")
        XCTAssertEqual(string(daysAgo: 13), "13 days ago")
    }

    func testWeeksAgo() {
        XCTAssertEqual(string(daysAgo: 14), "2 weeks ago")
        XCTAssertEqual(string(daysAgo: 21), "3 weeks ago")
    }

    // MARK: - Months

    func testOneMonthAgo() {
        XCTAssertEqual(string(monthsAgo: 1), "1 month ago")
    }

    func testMonthsAgo() {
        XCTAssertEqual(string(monthsAgo: 3),  "3 months ago")
        XCTAssertEqual(string(monthsAgo: 11), "11 months ago")
    }

    // MARK: - Years

    func testOneYearAgo() {
        XCTAssertEqual(string(yearsAgo: 1), "1 year ago")
    }

    func testOneYearOneMonthAgo() {
        XCTAssertEqual(string(yearsAgo: 1, extraMonths: 1), "1 year 1 month ago")
    }

    func testOneYearMultipleMonthsAgo() {
        XCTAssertEqual(string(yearsAgo: 1, extraMonths: 3), "1 year 3 months ago")
    }

    func testMultipleYearsAgo() {
        XCTAssertEqual(string(yearsAgo: 2), "2 years ago")
        XCTAssertEqual(string(yearsAgo: 5), "5 years ago")
    }
}

