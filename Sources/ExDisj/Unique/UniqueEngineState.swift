//
//  UniqueEngineState.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation

public actor UniqueEngineState {
    
    public struct Entry : Sendable {
        fileprivate init(forObj: ObjectIdentifier, _ data: Set<AnyUniqueId>) {
            self.inner = data;
            self.forObj = forObj;
        }
        
        private var inner: Set<AnyUniqueId>;
        private let forObj: ObjectIdentifier;
        
        public func isOpen<T>(id: T) -> Bool where T: UniqueId {
            self.inner.contains(.init(id));
        }
        public func isTaken<T>(id: T) -> Bool where T: UniqueId {
            !self.isOpen(id: id);
        }
        public mutating func reserveId<T>(id: T) throws(UniqueFailureError) where T: UniqueId {
            guard isOpen(id: id) else {
                throw UniqueFailureError(forObj: forObj, id: .init(id));
            }
            
            self.inner.insert(.init(id));
        }
        public mutating func releaseId<T>(id: T) where T: UniqueId {
            self.inner.remove(.init(id))
        }
        public mutating func swapId<T>(oldId: T, newId: T) throws(UniqueFailureError) where T: UniqueId {
            try self.reserveId(id: newId); // We reserve first, so that if the new ID is not unique, we will not corrupt inner state.
            self.releaseId(id: oldId);
        }
    }
    
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
            self.data[obj] = Entry(forObj: obj, Set())
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
    public func reserveId<T>(forObj: ObjectIdentifier, id: T) throws(UniqueFailureError) where T: UniqueId {
        try self[forObj]?.reserveId(id: id);
    }
    public func swapId<T>(forObj: ObjectIdentifier, oldId: T, newId: T) throws(UniqueFailureError) where T: UniqueId {
        try self[forObj]?.swapId(oldId: oldId, newId: newId)
    }
    
    public func reset() {
        self.data = [:]
    }
}
