//
//  CoreDataUniqueEnforcer.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation
import CoreData
import os

public actor CoreDataUniqueEnforcer<each T> : UniqueEnforcer
where repeat each T: NSManagedObject & UniqueElement {
    public var state: UniqueEngineState?;
    
    public init(container: NSPersistentContainer, logger: Logger?) async {
        self.logger = logger;
        self.container = container;
        self.cx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType);
        self.cx.persistentStoreCoordinator = container.persistentStoreCoordinator;
        self.cx.name = "UniqueEngine";
        self.cancel = nil;
        
        var targetTypes: Set<String> = .init();
        for M in repeat (each T).self {
            targetTypes.insert(
                M.entity().className
            )
        }
        
        self.targetTypes = targetTypes;
        
        self.cancel = await NotificationToken.createAsync(
            forName: .NSManagedObjectContextDidSave,
            object: container.viewContext
        ) { [weak self, targetTypes] notification in
            Self.onUpdateNotice(log: logger, notification: notification, targetTypes: targetTypes, inner: self)
        }
    }
    
    private let logger: Logger?;
    private let container: NSPersistentContainer;
    private let cx: NSManagedObjectContext;
    private var cancel: NotificationToken?;
    private let targetTypes: Set<String>;
    
    private static nonisolated func onUpdateNotice(log: Logger?, notification: Notification, targetTypes: Set<String>, inner: CoreDataUniqueEnforcer<repeat each T>?) {
        guard let inner else {
            log?.warning("Global CoreDataUniqueEnforcer: No enforcer to update.");
            return;
        }
        guard let info = notification.userInfo else {
            log?.warning("Global CoreDataUniqueEnforcer: Notification contained no payload.");
            return;
        }
        guard let context = notification.object as? NSManagedObjectContext else {
            log?.warning("Global CoreDataUniqueEnforcer: No managed object context given.");
            return;
        }
        
        log?.info("Global CoreDataUniqueEnforcer: Processing notification for context '\(context.name ?? "(No Name)")'");
        
        let insertedModels = (info[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? Set();
        let updatedModels = (info[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? Set();
        let deletedModels = (info[NSDeletedObjectsKey] as? Set<NSManagedObject>) ?? Set();
        
        var inserted: [ObjectIdentifier : Set<AnyHashable>] = [:];
        var updated: [ObjectIdentifier : Set<AnyHashable>] = [:];
        var deleted: [ObjectIdentifier : Set<AnyHashable>] = [:];
        
        for model in insertedModels {
            guard targetTypes.contains( model.entity.className ) else {
                continue;
            }
            
            // We know that it has to be a unique element.
            let asUnique = model as! UniqueElement;
            inserted[asUnique.getObjectId(), default: Set()].insert(asUnique.uID);
        }
        for model in updatedModels {
            guard targetTypes.contains( model.entity.className ) else {
                continue;
            }
            
            // We know that it has to be a unique element.
            let asUnique = model as! UniqueElement;
            updated[asUnique.getObjectId(), default: Set()].insert(asUnique.uID);
        }
        for model in deletedModels {
            guard targetTypes.contains( model.entity.className ) else {
                continue;
            }
            
            // We know that it has to be a unique element.
            let asUnique = model as! UniqueElement;
            deleted[asUnique.getObjectId(), default: Set()].insert(asUnique.uID);
        }
    }
    
    private typealias IdsDict = [ObjectIdentifier : Set<AnyHashable>];
    
    private func updateFromNotification(inserted: IdsDict, updated: IdsDict, deleted: IdsDict) {
        logger?.info("CoreDataUniqueEnforcer: Obtained message, performing update.");
        
        guard let state = self.state else {
            logger?.warning("CoreDataUniqueEnforcer: No state is given, ignoring notification.");
            return;
        }
        
        logger?.info("CoreDataUniqueEnforcer: Removing deleted items");
        
        
        
        for (object, removedIds) in deleted {
            
        }
    }
    
    private func fetchFor<M>(forType: M.Type) async throws -> UniqueIdentifierBundle
    where M: UniqueElement & NSManagedObject {
        let desc = NSFetchRequest<M>();
        logger?.debug("UniqueEngine: Processing type \(String(describing: M.self))");
        
        
        return try await cx.perform { [cx, logger] in
            let fetched = try cx.fetch(desc);
            var result = Set<AnyHashable>();
            for item in fetched {
                let id = AnyHashable(item.uID);
                
                guard !result.contains(id) else {
                    logger?.debug("UniqueEngine: Type '\(String(describing: M.self))' has a non-unique identifier: \(String(describing: item.uID))");
                    throw UniqueFailureError(value: id);
                }
                
                result.insert(id);
            }
            
            logger?.debug("UniqueEngine: Processed type \(String(describing: M.self))");
            return .init(id: M.objId, reserved: result);
        }
    }
    
    
    public func fetchAll() async throws -> UniqueContext {
        logger?.info("UniqueEngine: Begining database walk.");
        var result: Dictionary<ObjectIdentifier, Set<AnyHashable>> = .init();
        
        for M in repeat (each T).self {
            let partialResult = try await fetchFor(forType: M);
            
            result[partialResult.id] = partialResult.reserved;
        }
        logger?.info("UniqueEngine: Completed walk.");
        
        return .init(content: result);
    }
}
