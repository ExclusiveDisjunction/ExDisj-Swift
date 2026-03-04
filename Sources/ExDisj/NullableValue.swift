//
//  NullableValue.swift
//  Edmund
//
//  Created by Hollan Sellars on 12/26/25.
//

import Foundation
import SwiftUI
import Observation

/// The view model state for a nullable value.
@available(macOS 14, iOS 17, *)
@Observable
fileprivate class NullableValueBacking<C, T> where C: AnyObject {
    fileprivate init(_ source: C, _ path: WritableKeyPath<C, T?>, _ defaultValue: T) {
        self.source = source;
        self.path = path;
        self.defaultValue = defaultValue;
        self.oldValue = source[keyPath: path] ?? defaultValue;
    }
    
    private var source: C;
    private let path: WritableKeyPath<C, T?>;
    private let defaultValue: T;
    private var oldValue: T;
    
    /// Determines if there is a current value.
    fileprivate var hasValue: Bool {
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
    /// Gets the current value
    fileprivate var value: T {
        get {
            source[keyPath: path] ?? self.defaultValue
        }
        set {
            source[keyPath: path] = newValue;
        }
    }
    /// Gets the value out of the class
    fileprivate var classValue: T? {
        get {
            source[keyPath: path]
        }
        set {
            source[keyPath: path] = newValue;
        }
    }
}

/// A wrapper that allows you to wrap around a nullable value, and make it non-null with a boolean toggle.
///
/// Some properties of classes are nullable. For instance, consider a location for a possibly virtual event. This could be stored as `String?`.
/// However, binding to such a value in the UI is highly inconvenient. To solve this, one can use the ``NullableValue``. Consider the following example.
///
/// ```swift
/// @Observable
/// class BasicProperties {
///         public init(propA: Int, propB: String?) {
///             self.propA = propA;
///             self.propB = propB;
///         }
///
///         public var propA: Int;
///         public var propB: String?;
/// }
///
/// struct PropertiesViewer : View {
///     @Observable private var properties: BasicProperties;
///     @NullableValue<BasicProperties, String> propB: Binding<Bool>;
///
///     init(_ properties: BasicProperties) {
///         self.properties = properties;
///         self._propB = .init(properties, \.propB, "");
///     }
///
///     var body: some View {
///         VStack {
///             Toggle("Has Property B?", isOn: propB)
///             TextField("Property B", text: $propB)
///         }
///     }
///  }
///  ```
///
/// The example shows a class with a nullable property, and a view that binds to it.
/// The ``NullableValue/wrappedValue`` provides a boolean binding, indicating if a value is present,
/// while the ``NullableValue/projectedValue`` provides a binding to the actual value.
@available(macOS 14, iOS 17, *)
@propertyWrapper
public struct NullableValue<C, T> where C: AnyObject {
    public init(_ source: C, _ path: WritableKeyPath<C, T?>, _ defaultValue: T) {
        backing = NullableValueBacking(source, path, defaultValue)
    }
    
    @Bindable private var backing: NullableValueBacking<C, T>;
    
    /// A boolean binding that indicates if a value is present.
    public var wrappedValue: Binding<Bool> {
        $backing.hasValue
    }
    /// A binding to the value, defaulted if no value is present.
    public var projectedValue: Binding<T> {
        $backing.value
    }
}
