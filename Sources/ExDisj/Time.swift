//
//  TimePeriodWalker.swift
//  ExDisj
//
//  Created by Hollan Sellars on 8/21/25.
//

import Foundation
import SwiftUI

public enum TimePeriods: Int, CaseIterable, Identifiable, Equatable, Sendable, Comparable, Codable, Displayable {
    case weekly = 0
    case biWeekly = 1
    case monthly = 2
    case biMonthly = 3
    case quarterly = 4
    case semiAnually = 5
    case anually = 6
    
    private var index: Int {
        Int(self.rawValue)
    }
    private static let compTable: [[Decimal]] =
    [
    //   Week             Bi-Week          Month            Bi-Month         Quarter           Half-Year         Year
        [1.0000000000,    2.0000000000,    4.0000000000,    8.0000000000,    12.0000000000,    24.0000000000,    52.0000000000],
        [0.5000000000,    1.0000000000,    2.0000000000,    4.0000000000,    6.0000000000 ,    13.0000000000,    26.0000000000],
        [0.2500000000,    0.5000000000,    1.0000000000,    2.0000000000,    3.0000000000 ,    6.0000000000 ,    12.0000000000],
        [0.1250000000,    0.2500000000,    0.5000000000,    1.0000000000,    1.5000000000 ,    3.0000000000 ,    6.0000000000 ],
        [0.0833333333,    0.1666666667,    0.3333333333,    0.6666666667,    1.0000000000 ,    2.0000000000 ,    4.0000000000 ],
        [0.0416666667,    0.0833333333,    0.1666666667,    0.3333333333,    0.5000000000 ,    1.0000000000 ,    2.0000000000 ],
        [0.0192307692,    0.0384615385,    0.0833333333,    0.1666666667,    0.2500000000 ,    0.5000000000 ,    1.0000000000 ]

    ]
    
    public func conversionFactor(_ to: TimePeriods) -> Decimal {
        let i = self.index, j = to.index
        
        return TimePeriods.compTable[i][j]
    }
    public var asComponents: DateComponents {
        switch self {
            case .weekly:      .init(weekOfYear: 1)
            case .biWeekly:    .init(weekOfYear: 2)
            case .monthly:     .init(month: 1)
            case .biMonthly:   .init(month: 2)
            case .quarterly:   .init(month: 3)
            case .semiAnually: .init(month: 6)
            case .anually:     .init(year: 1)
        }
    }
    
    public var id: Self { self }
    
    public static func <(lhs: TimePeriods, rhs: TimePeriods) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    public var display: LocalizedStringKey {
        switch self {
        case .weekly: "Weekly"
        case .biWeekly: "Bi-Weekly"
        case .monthly: "Monthly"
        case .biMonthly: "Bi-Monthly"
        case .quarterly: "Quarterly"
        case .semiAnually: "Semi-Anually"
        case .anually: "Anually"
        }
    }
}

public enum MonthlyTimePeriods : Int16, CaseIterable, Identifiable, Equatable, Hashable, Sendable, Codable {
    case weekly = 0
    case biWeekly = 1
    case monthly = 2
    
    private var index: Int {
        Int(self.rawValue)
    }
    private static let facTable: [[Decimal]] =
    [
        //   Week,  Bi-Week, Month
        [ 1.0,  2.0,     4.0 ],
        [ 0.5,  1.0,     2.0 ],
        [ 0.25, 0.5,     1.0 ]
    ];
    
    public func conversionFactor(_ to: MonthlyTimePeriods) -> Decimal {
        let i = self.index, j = to.index;
        
        return Self.facTable[i][j];
    }
    public var asComponents: DateComponents {
        switch self {
            case .weekly:      .init(weekOfYear: 1)
            case .biWeekly:    .init(weekOfYear: 2)
            case .monthly:     .init(month: 1)
        }
    }
    
    public var id: Self { self }
}

public extension Date {
    static func fromParts(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }
}

public struct TimePeriodWalker {
    public init(start: Date, end: Date?, period: TimePeriods, calendar: Calendar) {
        if let end = end {
            assert(start < end, "The start date cannot be greater than or equal to the end date.")
        }
        
        self.start = start
        self.end = end
        self.period = period.asComponents
        self.calendar = calendar
        self.current = start
    }
    
    public let start: Date;
    public let end: Date?;
    public let calendar: Calendar;
    public private(set) var current: Date?;
    private let period: DateComponents;
    
    public mutating func reset() {
        self.current = start
    }
    
    public mutating func step() -> Date? {
        guard let current = self.current else { //This value will be the return value
            return nil
        }
        
        guard let nextDate: Date = calendar.date(byAdding: period, to: current) else { //this value will be the value in the next call
            return nil
        }
        
        if let end = end, nextDate > end {
            self.current = nil
        }
        else {
            self.current = nextDate
        }
        
        return current
    }
    public mutating func walkToDate(relativeTo: Date) -> Date? {
        guard start <= relativeTo else {
            if let end = end, start > end {
                return nil
            }
            
            return start
        }
        
        guard var current = self.current else {
            return nil
        }
        
        while current <= relativeTo {
            guard let value = self.step() else {
                return nil
            }
            
            current = value
        }
        
        if let end = end, current > end {
            return nil
        }
        
        return current
    }
    public mutating func step(periods: Int) -> [Date]? {
        guard self.current != nil else {
            return nil
        }
        
        var result: [Date] = [];
        var n = periods;
        while n >= 0 {
            if let nextDate = self.step() {
                result.append(nextDate)
                n -= 1
            }
            else {
                // The current next date could not be obtained. If this is because the current is nil (only happens when the end has been passed, we can just return now.
                if self.current == nil {
                    return result
                }
                else {
                    return nil //This means there was an internal error
                }
            }
        }
        
        return result
    }
}

/// A structure that encodes the month and year of some specific date.
public struct MonthYear : Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    /// Creates the `MonthYear` instance from  specific values.
    /// - Parameters:
    ///     - year: The target year
    ///     - month: The target month
    public init(_ year: Int, _ month: Int) {
        self.year = year
        self.month = month
    }
    /// Attempts to create the `MonthYear` from a date.
    /// - Parameters:
    ///     - date: The date to extract from
    ///     - calendar: The calendar used to extract components.
    /// - Note: This will return `nil` if the calendar is not able to extract the required components out of `date`.
    public init?(date: Date, calendar: Calendar = .current) {
        let comp = calendar.dateComponents([.year, .month], from: date);
        guard let year = comp.year, let month = comp.month else {
            return nil;
        }
        self.year = year
        self.month = month
    }
    
    /// The year associated with this data
    public let year: Int;
    /// The month associated with this data
    public let month: Int;
    
    public var description: String {
        "Month: \(month) Year: \(year)"
    }
    
    /// Determines the first day of the month encoded by this structure.
    public func start(calendar: Calendar = .current) -> Date? {
        calendar.date(from: .init(year: Int(self.year), month: Int(self.month), day: 1))
    }
    /// Determines the last day of the month encoded by this structure.
    public func end(calendar: Calendar = .current) -> Date? {
        guard let currentFirstDay = self.start(calendar: calendar),
              let followingFirstDay = calendar.date(byAdding: .month, value: 1, to: currentFirstDay),
              let currentLastDay = calendar.date(byAdding: .day, value: -1, to: followingFirstDay) else {
            return nil
        }
        
        return currentLastDay
    }
    
    /// Attempts to obtain the current month and year from `Date.now`.
    /// - Note: This will return `nil` if the current `Calendar` is not able to extract the required components to construct this instance.
    public static var now: MonthYear? {
        self.init(date: .now)
    }
    /// Attempts to obtain the current month and year from `Date.now` using a specific calendar.
    /// - Parameters:
    ///     - calendar: The calendar to use for date component extraction.
    /// - Note: This will return `nil` if the `Calendar` passed is not able to extract the required components to construct this instance.
    public static func now(calendar: Calendar) -> MonthYear? {
        self.init(date: .now, calendar: calendar)
    }
    
    public static func < (lhs: MonthYear, rhs: MonthYear) -> Bool {
        if lhs.year == rhs.year {
            lhs.month < rhs.month
        }
        else {
            lhs.year < rhs.year
        }
    }
}
