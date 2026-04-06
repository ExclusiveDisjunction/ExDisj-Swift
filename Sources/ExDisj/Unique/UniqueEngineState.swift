//
//  UniqueEngineState.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation

public actor UniqueEngineState {
    public init() {
        self.data = [:];
    }
    
    private var data: Dictionary<ObjectIdentifier, Set<AnyHashable>>;
    
    public func obtainState() -> UniqueContext {
        return .init(content: self.data)
    }
    public func releaseId<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId {
        data[forObj]?.remove(id) != nil
    }
    public func isIdOpen<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId {
        !data[forObj, default: .init()].contains(id)
    }
    public func isIdTaken<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId {
        data[forObj, default: .init()].contains(id);
    }
    public func reserveId<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId {
        data[forObj, default: .init()].insert(id).inserted
    }
    public func swapId<T>(forObj: ObjectIdentifier, oldId: T, newId: T) -> Bool where T: UniqueId {
        let _ = self.releaseId(forObj: forObj, id: oldId);
        return self.reserveId(forObj: forObj, id: newId);
    }
    
    public func setWith(content: UniqueContext) {
        self.data = content.content;
    }
    public func reset() {
        self.data = [:]
    }
}
