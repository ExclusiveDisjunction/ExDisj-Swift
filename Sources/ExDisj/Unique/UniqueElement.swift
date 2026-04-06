//
//  UniqueElement.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation

/// A protocol that determines if an element is unique.
/// For the unique pattern to work, the type must implement this protocol.
public protocol UniqueElement {
    associatedtype UID: UniqueId;
    
    static var objId: ObjectIdentifier { get }
    var uID: UID { get }
}
public extension UniqueElement {
    func getObjectId() -> ObjectIdentifier {
        Self.objId
    }
}
extension ValidationBuilderProtocol where Self: ~Copyable {
    public mutating func check<C>(prop: Fields, forType: C.Type = C.self, oldId: C.UID, newId: C.UID, unique: UniqueEngine) async
    where C: UniqueElement
    {
        let objId = forType.objId;
        await self.check(prop: prop, oldId: oldId, newId: newId) { id in
            await unique.isIdOpen(forObj: objId, id: newId);
        }
    }
    public mutating func check<T>(prop: Fields, forObject: ObjectIdentifier, oldId: T, newId: T, unique: UniqueEngine) async
    where T: UniqueId {
        await self.check(prop: prop, oldId: oldId, newId: newId) { id in
            await unique.isIdOpen(forObj: forObject, id: newId)
        }
    }
}
