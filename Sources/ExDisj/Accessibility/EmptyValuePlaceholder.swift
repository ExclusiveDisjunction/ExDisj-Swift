//
//  EmptyValuePlaceholder.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/14/26.
//

import SwiftUI


public struct EmptyValuePlaceholder<Value, Content> : View where Content: View {
    public init(_ value: Value, determine: @escaping (Value) -> Bool, @ViewBuilder content: @escaping (Value) -> Content) {
        self.value = value;
        self.determine = determine;
        self.content = content;
    }
    
    public let value: Value;
    public let determine: (Value) -> Bool;
    public let content: (Value) -> Content;
    
    public var body: some View {
        if determine(value) {
            content(value)
        }
        else {
            Text("-")
                .accessibilityLabel("No value")
        }
    }
}
extension EmptyValuePlaceholder where Content == Text {
    public init(_ value: Value) where Value: StringProtocol {
        self.init(
            value,
            determine: { !$0.isEmpty },
            content: { Text($0) }
        )
    }
    public init<F>(_ value: Value, format: F) where Value: BinaryInteger, F: FormatStyle, F.FormatInput == Value, F.FormatOutput == String {
        self.init(
            value,
            determine: { $0 != 0 },
            content: { Text($0, format: format) }
        )
    }
    
    public init(_ value: [String], separator: String = ", ") where Value == [String] {
        let combined = value.joined(separator: separator)
        self.init(
            value,
            determine: { !$0.isEmpty },
            content: { _ in Text(combined) }
        )
    }
    
    public init<S>(_ value: S?) where Value == S?, S: StringProtocol {
        self.init(
            value,
            determine: { str in
                guard let str = str else {
                    return false;
                }
                
                return !str.isEmpty
            },
            content: { Text($0!) }
        )
    }
    public init(_ value: Date?, date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) where Value == Date? {
        self.init(
            value,
            determine: { $0 != nil },
            content: { Text($0!.formatted(date: date, time: time))}
        )
    }
    public init(_ value: Date?) where Value == Date? {
        self.init(
            value,
            determine: { $0 != nil },
            content: { Text($0!.formatted()) }
        )
    }
    @available(macOS 13, iOS 16, *)
    public init(_ value: URL?) where Value == URL? {
        self.init(
            value,
            determine: { $0 != nil },
            content: { Text($0!.path()) }
        )
    }
}
