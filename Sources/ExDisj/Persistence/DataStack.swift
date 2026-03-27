//
//  DataStack.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/13/26.
//

@preconcurrency import CoreData
import SwiftData
import SwiftUI


/// An error describing a persistent store could not be loaded.
public struct ModelResolutionError : Error {
    public let name: String;
    
    public var description: String {
        "Unable to find model description named '\(name)'"
    }
}

public struct CoreDataSchemaManager {
    /// A coordination queue to manage ``loadedModels``.
    private static let queue: DispatchQueue = DispatchQueue(label: "DataStack");
    
    private nonisolated(unsafe) static var loadedModels: [String : NSManagedObjectModel] = [:];
    public static func resolveModel(withName: String) async throws -> NSManagedObjectModel {
        return try await withCheckedThrowingContinuation { cont in
            do {
                let result = try Self.queue.asyncAndWait {
                    if let model = Self.loadedModels[withName] {
                        return model;
                    }
                    
                    guard let url = Bundle.main.url(forResource: withName, withExtension: "momd") else {
                        throw ModelResolutionError(name: withName);
                    }
                    
                    guard let model = NSManagedObjectModel(contentsOf: url) else {
                        throw ModelResolutionError(name: withName);
                    }
                    
                    Self.loadedModels[withName] = model;
                    return model;
                };
                
                cont.resume(returning: result);
            }
            catch let e {
                cont.resume(throwing: e)
            }
        }
    }
    
    public static let nullModelName: String = "!NULL!";
    public static var nullModel: NSManagedObjectModel {
        get {
            return Self.queue.asyncAndWait {
                if let model = Self.loadedModels[Self.nullModelName] {
                    return model;
                }
                
                let model = NSManagedObjectModel();
                Self.loadedModels[Self.nullModelName] = model;
                
                return model;
            }
        }
    }
}

extension ContainerDescription where Container == NSPersistentContainer {
    public static func inMemory(
        schemaName name: String,
        onLoad: (@Sendable (NSManagedObjectContext) throws -> Void)? = nil
    ) -> Self {
        self.init(
            schemaLocator: {
                try await CoreDataSchemaManager.resolveModel(withName: name)
            },
            stores: {
                return [
                    .init(storeType: .inMemory, isReadOnly: false, automaticMigrations: true)
                ]
            },
            onLoad: onLoad
        )
    }
    public static func inMemory<B>(
        schemaName name: String,
        withBuilder: B,
        onLoad: (@Sendable (NSManagedObjectContext) throws -> Void)? = nil
    ) -> Self where B: ContainerDataFiller, B.Container == Container {
        self.init(
            schemaLocator: {
                try await CoreDataSchemaManager.resolveModel(withName: name)
            },
            stores: {
                return [
                    .init(storeType: .inMemory, isReadOnly: false, automaticMigrations: true)
                ]
            },
            onLoad: { context in
                try withBuilder.fill(context: context)
                if let onLoad {
                    try onLoad(context)
                }
            }
        )
    }
    
    public static func onDisk(
        schemaName name: String,
        path: URL,
        onLoad: (@Sendable (NSManagedObjectContext) throws -> Void)? = nil
    ) -> Self {
        self.init(
            schemaLocator: {
                try await CoreDataSchemaManager.resolveModel(withName: name)
            },
            stores: {
                return [
                    .init(storeType: .inFile(path), isReadOnly: false, automaticMigrations: true)
                ]
            },
            onLoad: onLoad
        )
    }
    public static func onDisk<B>(
        schemaName name: String,
        path: URL,
        withBuilder: B,
        onLoad: (@Sendable (NSManagedObjectContext) throws -> Void)? = nil
    ) -> Self where B: ContainerDataFiller, B.Container == Container {
        self.init(
            schemaLocator: {
                try await CoreDataSchemaManager.resolveModel(withName: name)
            },
            stores: {
                return [
                    .init(storeType: .inFile(path), isReadOnly: false, automaticMigrations: true)
                ]
            },
            onLoad: { context in
                try withBuilder.fill(context: context);
                if let onLoad {
                    try onLoad(context)
                }
            }
        )
    }
}

/// A all-in-one replacement for `NSPersistentContainer` that allows for deep customization of the core data stack.
///
/// Use a ``StoreDescription`` type to manage the loading of this instance.
public class DataStack : NSPersistentContainer, @unchecked Sendable {
    /// Loads the stack with a specific managed object model, the stores defined by `desc`, and the main-actor bound view context.
    /// - Parameters:
    ///     - desc: The store description instruct the loading process
    /// If the managed object model described by `desc` is already known to any instance of ``DataStack``, the `NSManagedObjectModel` instance will be reused.
    public init(desc: ContainerDescription<NSPersistentContainer>) async throws {
        let model = try await desc.schemaLocator();
        super.init(name: "DataStack", managedObjectModel: model);
        
        self.persistentStoreDescriptions = try desc.stores().map {
            $0.makePersistentContainerDescription()
        };
        
        try await withCheckedThrowingContinuation { (completion: CheckedContinuation<(), any Error>) in
            self.loadPersistentStores { (desc, err) in
                if let err {
                    completion.resume(throwing: err)
                }
                else {
                    completion.resume()
                }
            }
        }
        
        try await viewContext.perform { [viewContext, desc] in
            viewContext.automaticallyMergesChangesFromParent = true;
            viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
            
            if let onLoad = desc.onLoad {
                try onLoad(viewContext);
                try viewContext.save();
            }
        }
    }
    /// Opens a schema-less instance, with a read-only store and empty view context.
    ///
    /// This is the default value of the environment value, ``SwiftUICore/EnvironmentValues/dataStack``.
    public init() {
        let nullModel = CoreDataSchemaManager.nullModel;
        super.init(name: "NullModel", managedObjectModel: nullModel)
        
        self.persistentStoreDescriptions = [
            StoreDescription(storeType: .inMemory, isReadOnly: true, automaticMigrations: false)
                .makePersistentContainerDescription()
        ];
        
        self.loadPersistentStores { (_, err) in
            if let err {
                fatalError("Unable to create a null data stack, due to error \(err)");
            }
        }
    }
    
    public override func newBackgroundContext() -> NSManagedObjectContext {
        let result = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType);
        result.persistentStoreCoordinator = self.persistentStoreCoordinator;
        
        result.performAndWait {
            result.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
            result.automaticallyMergesChangesFromParent = true;
        }
        
        return result;
    }
}



fileprivate struct DataStackEnvKey : EnvironmentKey {
    typealias Value = DataStack;
    static var defaultValue: DataStack {
        return .init();
    }
}


public extension EnvironmentValues {
    var dataStack: DataStack {
        get { self[DataStackEnvKey.self] }
        set {
            self[DataStackEnvKey.self] = newValue;
            self.managedObjectContext = newValue.viewContext;
            self.managedObjectContext.undoManager = self.undoManager;
        }
    }
}
