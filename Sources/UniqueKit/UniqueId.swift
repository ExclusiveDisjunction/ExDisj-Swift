//
//  UniqueId.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation
import CoreData
import SwiftData

public protocol UniqueId : Hashable, Sendable, CustomStringConvertible { }
extension String : UniqueId { }
extension Int : UniqueId { }
extension Int8 : UniqueId { }
extension Int16 : UniqueId { }
extension Int32 : UniqueId { }
extension Int64 : UniqueId { }
extension UInt : UniqueId { }
extension UInt8 : UniqueId { }
extension UInt16 : UniqueId { }
extension UInt32 : UniqueId { }
extension UInt64 : UniqueId { }
extension UUID : UniqueId { }

public enum AnyModelId : Hashable, Sendable {
    case noId
    case coreData(NSManagedObjectID)
    case swiftData(PersistentIdentifier)
    
    public static func ==(lhs: AnyModelId, rhs: AnyModelId) -> Bool {
        if case .noId = lhs, case .noId = rhs {
            return true;
        }
        else if case .noId = lhs {
            return false
        }
        else if case .noId = rhs {
            return false
        }
        else {
            switch (lhs, rhs) {
                case (.coreData(let x), .coreData(let y)): return x == y
                case (.swiftData(let x), .swiftData(let y)): return x == y
                default: return false
            }
        }
    }
}


public struct AnyUniqueId : @unchecked Sendable, Hashable {
    public init<T>(_ value: T)
    where T: UniqueId {
        self.inner = value;
    }
    
    private let inner: AnyHashable;
    
    public func hash(into hasher: inout Hasher) {
        inner.hash(into: &hasher);
    }
    public static func ==(lhs: AnyUniqueId, rhs: AnyUniqueId) -> Bool {
        lhs.inner == rhs.inner
    }
    public static func ==<T>(lhs: AnyUniqueId, rhs: T) -> Bool
    where T: UniqueId {
        lhs.inner == AnyHashable(rhs)
    }
}
