//
//  UniqueFailureError.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation

/// An error that occurs when the unique engine cannot validate a claim to an ID, but was assumed to be a free value.
public struct UniqueFailureError : Error, @unchecked Sendable {
    public init(forObj: ObjectIdentifier, id: AnyUniqueId) {
        self.id = id;
        self.forObj = forObj;
    }
    
    /// The ID that was taken already
    public let id: AnyUniqueId;
    public let forObj: ObjectIdentifier;
    
    /// A description of what happened
    public var description: String {
        "For object '\(String(describing: forObj))`, the identifier '\(String(describing: id))` is not unique"
    }
}
