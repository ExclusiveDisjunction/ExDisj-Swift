//
//  ChangesDebouncer.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/21/26.
//

import Foundation

internal enum ChangesPriority : Sendable {
    case lhsPriority
    case rhsPriority
    case equalPriority
}

public struct DuplicateIdResult : Sendable {
    public init() {
        self.duplicates = [:];
    }
    public var duplicates: Dictionary<AnyUniqueId, [EntityContext]>;
    
    public mutating func register(id: AnyUniqueId, forModel: EntityContext) {
        self.duplicates[id, default: []].append(forModel);
    }
    
    public var isEmpty: Bool {
        self.duplicates.isEmpty
    }
}

internal struct ChangesPayload : Sendable {
    internal init() {
        self.register = [:];
        self.release = .init();
    }
    
    internal private(set) var register: Dictionary<AnyUniqueId, EntityContext>;
    internal private(set) var release: Set<AnyUniqueId>;
    
    internal mutating func newInserted(id: AnyUniqueId, model: AnyModelId) {
        self.register[id] = EntityContext(modelId: model);
    }
    internal mutating func newUpdated(oldId: AnyUniqueId, newId: AnyUniqueId, model: AnyModelId) {
        self.release.insert(oldId);
        self.newInserted(id: newId, model: model)
    }
    internal mutating func newDeleted(id: AnyUniqueId) {
        self.release.insert(id);
    }
    
    internal func combine(with: ChangesPayload, priority: ChangesPriority) -> (new: ChangesPayload, duplicates: DuplicateIdResult) {
        var result: ChangesPayload = .init();
        var duplicates: DuplicateIdResult = .init();
        let lhs = priority == .rhsPriority ? with : self;
        let rhs = priority == .rhsPriority ? self : with;
        let equal = priority == .equalPriority;
        
        // We first carry over the lhs data, since it will have a higher priority.
        // If duplicates are found, we can then throw if they are not equal
        result.insert = lhs.insert;
        result.update = lhs.update;
        
        for (id, model) in rhs.insert {
            if let payload = result.insert[id], model != payload { //If they point to the same object, we dont care.
                duplicates.register(id: id, forModel: payload);
                duplicates.register(id: id, forModel: model);
                
                continue;
            }
            
            result.insert[id] = model;
        }
        for (id, model) in rhs.update {
            if let payload = result.update[id], model != payload {
                duplicates.register(id: id, forModel: payload);
                duplicates.register(id: id, forModel: model);
                
                continue;
            }
            
            result.update[id] = model;
        }
        
        // Were deleting, so who really cares?
        result.delete = lhs.delete.union(rhs.delete);
        
        return (new: result, duplicates: duplicates);
    }
}

internal class ChangesDebouncer : @unchecked Sendable {
    
    
}
