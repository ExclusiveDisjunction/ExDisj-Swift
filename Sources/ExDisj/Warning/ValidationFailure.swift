//
//  ValidationFailure.swift
//  Edmund
//
//  Created by Hollan Sellars on 6/29/25.
//

import SwiftUI

/// A failure to validate a value out of a snapshot/element.
public enum ValidationFailureReason: Int, Identifiable, Sendable, Error {
    /// A uniqueness check failed over a set of identifiers.
    case unique
    /// A field was empty
    case empty
    /// A field was negative
    case negativeAmount
    /// A field is too large
    case tooLargeAmount
    /// A field is too small
    case tooSmallAmount
    /// A field has invalid input
    case invalidInput
    ///Happens when there is an internal expection that failed
    case internalError
    
    public var id: Self { self }
}

/// A builder structure to help list out ``ValidationFailureReason`` for properties.
public struct ValidationFailureBuilder : Sendable, ~Copyable {
    /// Constructs the builder with no intial failures.
    public init() {
        self.grievences = [:];
    }
    
    /// The issues observed as a series of property names and ``ValidationFailureReason``.
    public var grievences: [String : ValidationFailureReason];
    
    /// Adds a new failure.
    /// - Parameters:
    ///     - prop: The property the issue was observed with
    ///     - reason: The ``ValidationFailureReason`` observed with the property.
    public mutating func add(prop: String, reason: ValidationFailureReason) {
        self.grievences[prop] = reason;
    }
    
    /// Builds the failures together into a ``ValidationFailure`` if any issues were observed.
    /// - Returns: The ``ValidationFailure`` containing the issues. If no issues were reported, this will return `nil`.
    public consuming func build() -> ValidationFailure? {
        if self.grievences.isEmpty {
            return nil;
        } else {
            return ValidationFailure(self.grievences);
        }
    }
}

/// A user-based failure that indicates that there are problems with individual properties.
public struct ValidationFailure : Sendable, Error, WarningBasis {
    public init(_ grievences: [String : ValidationFailureReason]) {
        self.grievences = grievences;
        self.message = Self.buildMessage(grievences);
    }
    
    /// Builds the message from the properties and failures, using localization.
    private static func buildMessage(_ grievences: [String: ValidationFailureReason]) -> String {
        let header = NSLocalizedString("Please fix the following issues:\n", comment: "Validation Failure Header");
        
        var lines: [String] = [];
        let bundle = Bundle.main;
        for (prop, reason) in grievences {
            let propName = bundle.localizedString(forKey: prop, value: nil, table: nil);
            let fragment = switch reason {
                case .empty: "cannot be empty"
                case .invalidInput: "is invalid"
                case .negativeAmount: "cannot be negative"
                case .tooLargeAmount: "is too large"
                case .tooSmallAmount: "is too small"
                case .unique: "must be unique"
                case .internalError: "had an internal error"
            };
            
            let fragTrans = bundle.localizedString(forKey: fragment, value: nil, table: nil);
            let line = "\"\(propName)\" \(fragTrans)";
            lines.append(line)
        }
        
        let joinedLines = lines.joined(separator: "\n");
        
        return header + joinedLines;
    }
    
    /// The failures reported.
    public let grievences: [String: ValidationFailureReason];
    /// The message to present to the UI.
    public let message: String;
}
