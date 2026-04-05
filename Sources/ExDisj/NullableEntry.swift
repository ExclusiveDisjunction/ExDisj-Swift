//
//  NullableEntry.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/4/26.
//

import Foundation
import SwiftUI

@propertyWrapper
public struct NullableEntry<T> {
    public struct Entry {
        public let hasValue: Binding<Bool>;
        public let value: Binding<T>;
    }
    
    private let hasValue: Binding<Bool>;
    private let value: Binding<T>;
    
    public var wrappedValue: T? {
        hasValue.wrappedValue ? value.wrappedValue : nil;
    }
    public var projectedValue: Entry {
        return .init(hasValue: hasValue, value: value)
    }
}
extension NullableEntry {
    fileprivate class Backing : @unchecked Sendable {
        public init(value: T, hasValue: Bool) {
            self.value = value;
            self.hasValue = hasValue;
        }
        
        fileprivate var value: T;
        fileprivate var hasValue: Bool;
    }
    
    /// Constructs  an entry that is always `nil`, and cannot be changed.
    /// - Warning: Only use this in case of a temporary construction. If the value is accessed, it will result in a fatal error.
    public static var placeholder: NullableEntry<T> {
        NullableEntry(
            hasValue: .constant(false),
            value: Binding<T> {
                fatalError("Accessing a nullable entry before initalizing.")
            } set: { _ in }
        )
    }
    
    public init(_ from: T?, onDefault: T) {
        let backing = Self.Backing(value: from ?? onDefault, hasValue: from != nil);
        
        self.init(
            hasValue: Binding<Bool>(
                get: { backing.hasValue },
                set: { backing.hasValue = $0 }
            ),
            value: Binding<T>(
                get: { backing.value },
                set: { backing.value = $0 }
            )
        )
    }
    
    fileprivate class SourcedBacking<C> : @unchecked Sendable where C: AnyObject {
        init(source: C, path: WritableKeyPath<C, T?>, onDefault: T) {
            self.source = source;
            self.path = path;
            self.onDefault = onDefault;
        }
        
        fileprivate var source: C;
        fileprivate let onDefault: T;
        fileprivate let path: WritableKeyPath<C, T?>;
        
        var hasValue: Bool {
            get {
                source[keyPath: path] != nil;
            }
            set {
                guard hasValue != newValue else {
                    return
                }
                
                if newValue {
                    source[keyPath: path] = onDefault;
                }
                else {
                    source[keyPath: path] = nil;
                }
            }
        }
        var value: T {
            get {
                source[keyPath: path] ?? onDefault
            }
            set {
                source[keyPath: path] = newValue;
            }
        }
    }
    
    public init<C>(source: C, path: WritableKeyPath<C, T?>, onDefault: T)
    where C: AnyObject {
        let backing = SourcedBacking(source: source, path: path, onDefault: onDefault);
        
        self.init(
            hasValue: Binding<Bool> { backing.hasValue } set: { backing.hasValue = $0 },
            value: Binding<T> { backing.value } set: { backing.value = $0 }
        )
    }
    
    fileprivate class DeterminedBacking : @unchecked Sendable {
        init(initial: T, hasValue: @escaping () -> Bool) {
            self.determineValue = hasValue;
            self.value = initial;
        }
        
        fileprivate let determineValue: () -> Bool;
        fileprivate var value: T;
        
        var hasValue: Bool {
            determineValue()
        }
    }
    
    public init(initial: T, hasValue: @escaping () -> Bool) {
        let backing = DeterminedBacking(initial: initial, hasValue: hasValue);
        
        self.init(
            hasValue: Binding<Bool> { backing.hasValue } set: { _ in },
            value: Binding<T> { backing.value } set: { backing.value = $0 }
        )
    }
}

extension NullableEntry where T: DefaultableElement {
    public init(_ from: T?) {
        self.init(from, onDefault: T.init())
    }
    public init<C>(source: C, path: WritableKeyPath<C, T?>)
    where C: AnyObject {
        self.init(source: source, path: path, onDefault: T.init())
    }
}
extension NullableEntry where T: BinaryInteger {
    public init(_ from: T?) {
        self.init(from, onDefault: 0)
    }
    public init<C>(source: C, path: WritableKeyPath<C, T?>)
    where C: AnyObject {
        self.init(source: source, path: path, onDefault: 0)
    }
}
extension NullableEntry where T: BinaryFloatingPoint {
    public init(_ from: T?) {
        self.init(from, onDefault: 0)
    }
    public init<C>(source: C, path: WritableKeyPath<C, T?>)
    where C: AnyObject {
        self.init(source: source, path: path, onDefault: 0)
    }
}
extension NullableEntry where T == Decimal {
    public init(_ from: T?) {
        self.init(from, onDefault: 0)
    }
    public init<C>(source: C, path: WritableKeyPath<C, T?>)
    where C: AnyObject {
        self.init(source: source, path: path, onDefault: 0)
    }
}
extension NullableEntry where T == String {
    public init(_ from: T?) {
        self.init(from, onDefault: "")
    }
    public init<C>(source: C, path: WritableKeyPath<C, T?>)
    where C: AnyObject {
        self.init(source: source, path: path, onDefault: "")
    }
}

extension NullableEntry : Equatable where T: Equatable {
    public static func ==(lhs: NullableEntry<T>, rhs: NullableEntry<T>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}
extension NullableEntry : Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}

@available(*, unavailable, message: "There are no guarentees of thread safety")
extension NullableEntry : Sendable {
    
}

public struct NullableFormEntry<T, Content>{
    
    private let title: String;
    private let content: (Binding<T>) -> Content;
    private let entry: NullableEntry<T>.Entry;
    
    private var hasValue: Bool {
        self.entry.hasValue.wrappedValue;
    }
    
}
extension NullableFormEntry : View where Content: View {
    public init(_ title: String, entry: NullableEntry<T>.Entry, @ViewBuilder content: @escaping (Binding<T>) -> Content) {
        self.title = title;
        self.entry = entry;
        self.content = content;
    }
    
    public var body: some View {
        Toggle("Has \(title)?", isOn: entry.hasValue)
        
        content(entry.value)
            .disabled(!hasValue)
            .opacity(hasValue ? 1.0 : 0.5)
    }
}
extension NullableFormEntry where Content == TextField<Text> {
    public init(_ title: String, entry: NullableEntry<T>.Entry, withColon: Bool = true)
    where T == String
    {
        self.title = title;
        self.entry = entry;
        self.content = { $text in
            TextField(withColon ? "\(title):" : title, text: $text)
        }
    }
    public init<F>(_ title: String, entry: NullableEntry<T>.Entry, format: F, withColon: Bool = true)
    where F: ParseableFormatStyle,
          F.FormatInput == T,
          F.FormatOutput == String
    {
        self.title = title;
        self.entry = entry;
        self.content = { $value in
            TextField(withColon ? "\(title):" : title, value: $value, format: format)
        }
    }
}
extension NullableFormEntry {
    public init(
        _ title: String,
        entry: NullableEntry<T>.Entry,
        displayedComponents: DatePicker<Text>.Components,
        withColon: Bool = true
    ) where Content == DatePicker<Text>,
            T == Date
    {
        self.title = title;
        self.entry = entry;
        self.content = { $value in
            DatePicker(withColon ? "\(title):" : title, selection: $value, displayedComponents: displayedComponents)
        }
    }
}
extension NullableFormEntry {
    @MainActor
    public init(
        _ title: String,
        entry: NullableEntry<T>.Entry,
        withColon: Bool = true
    ) where Content == EnumPicker<T> {
        self.title = title;
        self.entry = entry;
        self.content = { $value in
            EnumPicker(withColon ? "\(title):" : title, value: $value)
        }
    }
}

#Preview {
    @Previewable @NullableEntry<String>(nil) var entry1: String?;
    @Previewable @NullableEntry<Int>(4) var entry2: Int?;
    @Previewable @NullableEntry<Date>(nil, onDefault: .now) var entry3: Date?;
    
    Form {
        NullableFormEntry("Text", entry: $entry1)
        NullableFormEntry("Num", entry: $entry2, format: .number)
        NullableFormEntry("Date", entry: $entry3, displayedComponents: .date)
    }.padding()
}
