//
//  UniqueFailureError.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation

/// An error that occurs when the unique engine cannot validate a claim to an ID, but was assumed to be a free value.
public struct UniqueFailureError : Error, @unchecked Sendable {
    /// The ID that was taken already
    public let value: AnyHashable
    
    /// A description of what happened
    public var description: String {
        "A uniqueness check failed for identifier \(value)"
    }
    public var localizedDescription: String {
        "The uniqueness constraint failed for this value. Please cancel the edit and try again."
    }
}
