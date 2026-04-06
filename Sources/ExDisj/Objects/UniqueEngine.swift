//
//  IDRegistry.swift
//  Edmund
//
//  Created by Hollan Sellars on 6/11/25.
//

import Foundation
import SwiftUI
import SwiftData
import os
import ExDisj

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

/// An error that occurs when the unique engine cannot validate a claim to an ID, but was assumed to be a free value.
public struct UniqueFailureError : Error, @unchecked Sendable {
    /// The ID that was taken already
    public let value: AnyHashable
    
    /// A description of what happened
    public var description: String {
        "A uniqueness check failed for identifier \(value)"
    }
    public var localizedDescription: LocalizedStringKey {
        "The uniqueness constraint failed for this value. Please cancel the edit and try again."
    }
}

/// An environment safe class that can be used to enforce the uniqueness amongts different objects of the same type.
public actor UniqueEngine {
    /// Creates the engine with empty sets.
    public init(_ logger: Logger? = nil) {
        self.data = .init();
        self.logger = logger;
    }
    
    private var logger: Logger?;
    private var data: Dictionary<ObjectIdentifier, Set<AnyHashable>>;
    
    private struct IdentifierBundle : @unchecked Sendable {
        let id: ObjectIdentifier;
        let reserved: Set<AnyHashable>;
    }
    
    private func fetchFor<T>(forType: T.Type, store: ModelContainer) async throws -> IdentifierBundle
    where T: UniqueElement & PersistentModel {
        let desc = FetchDescriptor<T>();
        logger?.debug("UniqueEngine: Processing type \(String(describing: T.self))");
        
        return try await Task(priority: .background) {
            let cx = ModelContext(store);
            
            let fetched: [T] = try cx.fetch(desc);
            var result = Set<AnyHashable>();
            for item in fetched {
                let id = AnyHashable(item.uID);
                
                guard !result.contains(id) else {
                    logger?.debug("UniqueEngine: Type '\(String(describing: T.self))' has a non-unique identifier: \(String(describing: item.uID))");
                    throw UniqueFailureError(value: id);
                }
                
                result.insert(id);
            }
            
            logger?.debug("UniqueEngine: Processed type \(String(describing: T.self))");
            return .init(id: T.objId, reserved: result);
        }.value;
    }
    private func fetchFor<T>(forType: T.Type, store: NSPersistentContainer) async throws -> IdentifierBundle
    where T: UniqueElement & NSManagedObject {
        let desc = NSFetchRequest<T>();
        logger?.debug("UniqueEngine: Processing type \(String(describing: T.self))");
        
        let cx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType);
        cx.persistentStoreCoordinator = store.persistentStoreCoordinator;
        
        return try await cx.perform { [logger] in
            let fetched = try cx.fetch(desc);
            var result = Set<AnyHashable>();
            for item in fetched {
                let id = AnyHashable(item.uID);
                
                guard !result.contains(id) else {
                    logger?.debug("UniqueEngine: Type '\(String(describing: T.self))' has a non-unique identifier: \(String(describing: item.uID))");
                    throw UniqueFailureError(value: id);
                }
                
                result.insert(id);
            }
            
            logger?.debug("UniqueEngine: Processed type \(String(describing: T.self))");
            return .init(id: T.objId, reserved: result);
        }
    }
    
    public func fill<each C>(store: ModelContainer, forModels: repeat (each C).Type) async throws
    where repeat each C: UniqueElement & PersistentModel {
        logger?.info("UniqueEngine: Begining database walk.");
        var result: Dictionary<ObjectIdentifier, Set<AnyHashable>> = .init();
        
        for model in repeat (each forModels) {
            let partialResult = try await fetchFor(forType: model, store: store);
            
            result[partialResult.id] = partialResult.reserved;
        }
        
        logger?.info("UniqueEngine: Completed walk.");
        
        self.data = result;
    }
    public func fill<each C>(store: NSPersistentContainer, forModels: repeat (each C).Type) async throws
    where repeat each C: UniqueElement & NSManagedObject {
        logger?.info("UniqueEngine: Begining database walk.");
        var result: Dictionary<ObjectIdentifier, Set<AnyHashable>> = .init();
        
        for model in repeat (each forModels) {
            let partialResult = try await fetchFor(forType: model, store: store);
            
            result[partialResult.id] = partialResult.reserved;
        }
        
        logger?.info("UniqueEngine: Completed walk.");
        
        self.data = result;
    }
    
    public func reset() {
        self.data = [:]
    }
    
    
    /// Determines if a specific ID (attached to an object ID) is not being used.
    public nonisolated func isIdOpen<T>(fromObject: T.Type = T.self, id: T.UID) async -> Bool where T: UniqueElement {
        await self.isIdOpen(forObj: fromObject.objId, id: id)
    }
    public func isIdOpen<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId {
        !data[forObj, default: .init()].contains(id)
    }
    
    /// Determines if a specific ID (attached to an object ID) is  being used.
    public nonisolated func isIdTaken<T>(fromObject: T.Type = T.self, id: T.UID) async -> Bool where T: UniqueElement {
        await self.isIdOpen(forObj: fromObject.objId, id: id);
    }
    public func isIdTaken<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId {
        data[forObj, default: .init()].contains(id)
    }
    
    /// Attempts to reserve an ID for a specific object ID.
    public nonisolated func reserveId<T>(fromObject: T.Type = T.self, id: T.UID) async -> Bool where T: UniqueElement {
        await self.reserveId(forObj: fromObject.objId, id: id);
    }
    public func reserveId<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId {
        let result = data[forObj, default: .init()].insert(id).inserted
        if !result {
            logger?.error("Reservation of id \(id.description) is already taken.")
        }
        // Since `inserted` will be false if the insert fails, this reserve call will also fail.
        return result
    }
    
    /// Attempts to release an ID from an object ID's pool.
    @discardableResult
    public func releaseId<T>(forObj: ObjectIdentifier, id: T) -> Bool where T: UniqueId  {
        data[forObj]?.remove(id) != nil
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
    public func swapId<T>(forObj: ObjectIdentifier, oldId: T, newId: T) -> Bool where T: UniqueId {
        let _ = self.releaseId(forObj: forObj, id: oldId)
        return self.reserveId(forObj: forObj, id: newId)
    }
}

 extension EnvironmentValues {
    /// A global value for the unique engine. This will always exist.
    @Entry public var uniqueEngine: UniqueEngine = UniqueEngine();
}
