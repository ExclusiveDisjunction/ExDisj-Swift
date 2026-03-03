//
//  NullableValue.swift
//  Edmund
//
//  Created by Hollan Sellars on 12/26/25.
//

import Foundation
import SwiftUI


import Observation

@available(macOS 14, iOS 17, *)
@Observable
public class NullableValueBacking<C, T> where C: AnyObject {
    fileprivate init(_ source: C, _ path: WritableKeyPath<C, T?>, _ defaultValue: T) {
        self.source = source;
        self.path = path;
        self.defaultValue = defaultValue;
        self.oldValue = source[keyPath: path] ?? defaultValue;
    }
    
    fileprivate var source: C;
    fileprivate let path: WritableKeyPath<C, T?>;
    fileprivate let defaultValue: T;
    private var oldValue: T;
    
    public var hasValue: Bool {
        get {
            classValue != nil
        }
        set {
            if newValue {
                classValue = oldValue;
            }
            else {
                oldValue = classValue ?? self.defaultValue;
                classValue = nil;
            }
        }
    }
    public var value: T {
        get {
            source[keyPath: path] ?? self.defaultValue
        }
        set {
            source[keyPath: path] = newValue;
        }
    }
    public var classValue: T? {
        get {
            source[keyPath: path]
        }
        set {
            source[keyPath: path] = newValue;
        }
    }
}

@available(macOS 14, iOS 17, *)
@propertyWrapper
public struct NullableValue<C, T> where C: AnyObject {
    public init(_ source: C, _ path: WritableKeyPath<C, T?>, _ defaultValue: T) {
        backing = NullableValueBacking(source, path, defaultValue)
    }
    
    @Bindable private var backing: NullableValueBacking<C, T>;
    
    public var wrappedValue: Binding<Bool> {
        $backing.hasValue
    }
    public var projectedValue: Binding<T> {
        $backing.value
    }
}
