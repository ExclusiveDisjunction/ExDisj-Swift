//
//  Warning.swift
//  Edmund
//
//  Created by Hollan Sellars on 4/22/25.
//

import SwiftUI

/// A simple basis for what warnings should include.
public protocol WarningBasis  {
    /// The encoded message that the warning presents.
    var message: String { get }
}

/// The warning message to be presented.
public enum SelectionWarningKind: Int, Identifiable, WarningBasis {
    
    /// The warning that no elements are selected, when at least one was expected.
    case noneSelected = 0
    /// The warning that too many elements are selected, as only one was expected.
    case tooMany = 1
    
    public var id: Self { self }
    /// Returns the `String` that  represents the warning.
    public var message: String {
        switch self {
            case .noneSelected: "Please select at one item."
            case .tooMany:      "Please select only one item."
        }
    }
}

/// A string-based message used to indicate errors for the UI.
public struct StringWarning: Identifiable, WarningBasis {
    public init(_ message: String, id: UUID = UUID()) {
        self.message = message
        self.id = id
    }
    /// The message to present to the UI.
    public let message: String
    
    public var id: UUID;
}

/// A warning that displays a message about an internal error.
public struct InternalErrorWarning : WarningBasis {
    /// The Internal Error message, which instructs the user to report the error.
    public static let internalError: String = "We are sorry, but an internal error has occured. Please report this issue."
    
    public var message: String { Self.internalError }
}

/// An observable class that provides warning funcntionality. It includes a memeber, `isPresented`, which can be bound. This value will become `true` when the internal `warning` is not `nil`.
@available(macOS 14, iOS 17, *)
@Observable
public class WarningManifest<T> where T: WarningBasis {
    /// Creates a new manifest without a warning.
    public init() {
        warning = nil;
    }
    
    /// The warning to present, if such a warning is active.
    public var warning: T?;
    /// The current message of the warning, if such a warning is active.
    public var message: String? { warning?.message }
    /// Determines if the manifest has a warning to present.
    ///
    /// The setter is designed for setting the `newValue` to `false`. No matter what, it will set the ``warning`` to `nil`.
    public var isPresented: Bool {
        get { warning != nil }
        set {
            if self.isPresented == newValue { return }
            
            warning = nil
        }
    }
}

/// A specalized version of ``WarningManifest`` that works for ``SelectionWarningKind`` values.
@available(macOS 14, iOS 17, *)
public typealias SelectionWarningManifest = WarningManifest<SelectionWarningKind>;

/// A specalized version of ``WarningManifest`` that works for ``StringWarning`` values.
@available(macOS 14, iOS 17, *)
public typealias StringWarningManifest = WarningManifest<StringWarning>

/// A specialed version of ``WarningManifest`` that works for ``ValidationFailure``/
@available(macOS 14, iOS 17, *)
public typealias ValidationWarningManifest = WarningManifest<ValidationFailure>;

/// A specialized version of ``WarningManifest`` to display internal error warnings.
@available(macOS 14, iOS 17, *)
public typealias InternalWarningManifest = WarningManifest<InternalErrorWarning>;

/// A view modifier that connects an `.alert` to the view. This alert activates when the ``WarningManifest`` activates.
@available(macOS 14, iOS 17, *)
fileprivate struct WarningManifestExtension<T> : ViewModifier where T: WarningBasis {
    public init(from: WarningManifest<T>) {
        self.from = from;
    }
    
    @Bindable private var from: WarningManifest<T>;
    
    public func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $from.isPresented) {
                Button("Save") {
                    from.isPresented = false
                }
            } message: {
                Text(verbatim: from.warning?.message ?? InternalErrorWarning.internalError)
            }
    }
}

extension View {
    /// Connects an `.alert` to the view. This alert activates when the ``WarningManifest`` activates.
    @available(macOS 14, iOS 17, *)
    public func withWarning<T>(_ manifest: WarningManifest<T>) -> some View
    where T: WarningBasis {
        self.modifier(WarningManifestExtension(from: manifest))
    }
}
