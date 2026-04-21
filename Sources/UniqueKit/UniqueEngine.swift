//
//  IDRegistry.swift
//  Edmund
//
//  Created by Hollan Sellars on 6/11/25.
//

import Foundation
import SwiftUI
import os

/// An environment safe class that can be used to enforce the uniqueness amongts different objects of the same type.
public actor UniqueEngine {
    /// Creates the engine with empty sets.
    public init(_ logger: Logger? = nil, using: any UniqueEnforcer) {
        self.state = .init();
        self.logger = logger;
        self.enforcer = using;
        
    }
    
    private var logger: Logger?;
    private let state: UniqueEngineState;
    private let enforcer: any UniqueEnforcer;
    
    public func reset() async {
        await self.state.reset();
    }
    
    /// Determines if a specific ID (attached to an object ID) is not being used.
    public nonisolated func isIdOpen<T>(fromObject: T.Type = T.self, id: T.UID) async -> Bool where T: UniqueElement {
        await self.isIdOpen(forObj: fromObject.objId, id: id)
    }
    public func isIdOpen<T>(forObj: ObjectIdentifier, id: T) async -> Bool where T: UniqueId {
        await self.state.isIdOpen(forObj: forObj, id: id);
    }
    
    /// Determines if a specific ID (attached to an object ID) is  being used.
    public nonisolated func isIdTaken<T>(fromObject: T.Type = T.self, id: T.UID) async -> Bool where T: UniqueElement {
        await self.isIdOpen(forObj: fromObject.objId, id: id);
    }
    public func isIdTaken<T>(forObj: ObjectIdentifier, id: T) async -> Bool where T: UniqueId {
        await self.state.isIdTaken(forObj: forObj, id: id);
    }
    
    /// Attempts to reserve an ID for a specific object ID.
    public nonisolated func reserveId<T>(fromObject: T.Type = T.self, id: T.UID) async -> Bool where T: UniqueElement {
        await self.reserveId(forObj: fromObject.objId, id: id);
    }
    public func reserveId<T>(forObj: ObjectIdentifier, id: T) async -> Bool where T: UniqueId {
        await self.state.reserveId(forObj: forObj, id: id)
    }
    
    /// Attempts to release an ID from an object ID's pool.
    @discardableResult
    public func releaseId<T>(forObj: ObjectIdentifier, id: T) async -> Bool where T: UniqueId {
        await self.state.releaseId(forObj: forObj, id: id);
    }
    /// Attempts to release an ID from an object ID's pool.
    @discardableResult
    public nonisolated func releaseId<T>(fromObject: T.Type = T.self, id: T.UID) async -> Bool where T: UniqueElement  {
        await self.releaseId(forObj: T.objId, id: id)
    }
    
    /// Releases and then attempts to obtain a new ID for a specific type.
    public func swapId<T>(fromObject: T.Type = T.self, oldId: T.UID, newId: T.UID) async -> Bool where T: UniqueElement {
        let _ = await self.releaseId(fromObject: fromObject, id: oldId)
        return await self.reserveId(fromObject: fromObject, id: newId)
    }
    public func swapId<T>(forObj: ObjectIdentifier, oldId: T, newId: T) async -> Bool where T: UniqueId {
        await self.state.swapId(forObj: forObj, oldId: oldId, newId: newId);
    }
}

extension EnvironmentValues {
    /// A global value for the unique engine. This will always exist.
    @Entry public var uniqueEngine: UniqueEngine = UniqueEngine(using: SimpleUniqueEnforcer());
}
