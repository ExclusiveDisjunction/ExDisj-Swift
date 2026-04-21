//
//  UniqueEngineState.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation

public struct EntityContext : Sendable, Hashable {
    public internal(set) var modelId: AnyModelId;
}

public struct Entry : Sendable {
    fileprivate init(forObj: ObjectIdentifier) {
        self.inner = [:];
        self.forObj = forObj;
    }
    
    private var inner: Dictionary<AnyUniqueId, EntityContext>;
    private let forObj: ObjectIdentifier;
    
    public func isOpen<T>(id: T) -> Bool where T: UniqueId {
        self.inner[ AnyUniqueId(id) ] != nil;
    }
    public func isTaken<T>(id: T) -> Bool where T: UniqueId {
        !self.isOpen(id: id);
    }
    public mutating func reserveId<T, M>(id: T, forModel: M) throws(UniqueFailureError) where T: UniqueId, M: ModelId {
        guard isOpen(id: id) else {
            throw UniqueFailureError(forObj: forObj, id: .init(id));
        }
        
        self.inner[ AnyUniqueId(id) ] = .init(modelId: AnyModelId(forModel) );
    }
    public mutating func releaseId<T>(id: T) where T: UniqueId {
        self.inner[ AnyUniqueId(id) ] = nil;
    }
    public mutating func swapId<T, M>(oldId: T, newId: T, forModel: M) throws(UniqueFailureError) where T: UniqueId, M: ModelId {
        try self.reserveId(id: newId, forModel: forModel); // We reserve first, so that if the new ID is not unique, we will not corrupt inner state.
        self.releaseId(id: oldId);
    }
}

public actor State {
    public init() {
        self.data = [:];
    }
    
    private var data: Dictionary<ObjectIdentifier, Entry>;
    
    public func obtainState() -> Dictionary<ObjectIdentifier, Entry> {
        self.data
    }
    
    public subscript(_ obj: ObjectIdentifier) -> Entry? {
        get {
            self.data[obj]
        }
        set {
            if let newValue {
                self.data[obj] = newValue;
            }
        }
    }
    
    public func registerType(obj: ObjectIdentifier) {
        if self.data[obj] == nil {
            self.data[obj] = Entry(forObj: obj)
        }
    }
    
    public func isOpen<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId {
        self[forObj]?.isOpen(id: id) ?? false;
    }
    public func isTaken<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId {
        self[forObj]?.isTaken(id: id) ?? true;
    }
    public func releaseId<T>(forObj: ObjectIdentifier, id: T) where T: UniqueId {
        self[forObj]?.releaseId(id: id)
    }
    public func reserveId<T, M>(forObj: ObjectIdentifier, id: T, forModel: M) throws(UniqueFailureError) where T: UniqueId, M: ModelId {
        try self[forObj]?.reserveId(id: id, forModel: forModel);
    }
    public func swapId<T, M>(forObj: ObjectIdentifier, oldId: T, newId: T, forModel: M) throws(UniqueFailureError) where T: UniqueId, M: ModelId {
        try self[forObj]?.swapId(oldId: oldId, newId: newId, forModel: forModel)
    }
    
    public func reset() {
        self.data = [:]
    }
}
