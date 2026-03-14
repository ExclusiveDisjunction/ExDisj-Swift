//
//  DataStack.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/13/26.
//

@preconcurrency import CoreData
import SwiftUI

/// A type that can be used to fill in dummy data for a `NSManagedObjectContext`.
public protocol ContainerDataFiller : Sendable {
    /// Given the `context`, fill out the container's values.
    /// - Parameters:
    ///     - context: The `NSManagedObjectContext` to insert to.
    func fill(context: NSManagedObjectContext) throws;
}

/// A structure that can instruct ``DataStack`` on how to build the core data stack.
public protocol StoreDescription : Sendable {
    /// The name of the model file to load. This should be in the bundle's resources, with extension `momd`.
    var modelName: String { get }
    /// Instructs the data stack to perform lightweight migrations.
    var automaticLightweightMigrations: Bool { get }
    
    /// Returns the persistent stores associated with this description.
    func withPersistentStores() throws -> [NSPersistentStoreDescription];
    /// After the stack has been loaded, an optional closure to perform.
    /// - Parameters:
    ///     - cx: The object context to modify once loaded.
    ///
    /// Before this call is made, it is guarenteed that we are within a `NSManagedObjectContext/perform` block, so any operation on `cs` is thread save.
    func onLoad(cx: NSManagedObjectContext) throws;
}
extension StoreDescription {
    /// Returns an in-memory persistent store for a specific model name.
    public static func inMemory(modelName: String, automaticMigrations: Bool = true) -> InMemoryStoreDescription where Self == InMemoryStoreDescription {
        return InMemoryStoreDescription(modelName: modelName, automaticLightweightMigrations: automaticMigrations)
    }
    /// Returns a data filler around a ``StoreDescription`` backend.
    /// - Parameters:
    ///     - filler: The ``ContainerDataFiller`` to put template data into the persistent store, once loaded.
    ///     - backing: The physical store description used to manage the location of persistent stores.
    /// While technically possible, `B` can be another ``BuildStoreDescription``, but this is undefined behavior.
    public static func builder<F, B>(filler: F, backing: B) -> BuilderStoreDescription<F, B> where F: ContainerDataFiller, B: StoreDescription, Self == BuilderStoreDescription<F, B> {
        return BuilderStoreDescription(builder: filler, desc: backing)
    }
    /// Returns file specific persistent store(s) for a specific model name.
    public static func standard(modelName: String, automaticMigrations: Bool = true, path: URL...) -> StandardStoreDescription where Self == StandardStoreDescription {
        return StandardStoreDescription(modelUrl: path, modelName: modelName, automaticLightweightMigrations: automaticMigrations)
    }
}

/// An in-memory persistent store for a specific model name.
public struct InMemoryStoreDescription : StoreDescription {
    public init(modelName: String, automaticLightweightMigrations: Bool) {
        self.modelName = modelName
        self.automaticLightweightMigrations = automaticLightweightMigrations
    }
    
    public let modelName: String;
    public let automaticLightweightMigrations: Bool;
    
    public func withPersistentStores() throws -> [NSPersistentStoreDescription] {
        let desc = NSPersistentStoreDescription();
        desc.type = NSInMemoryStoreType;
        
        return [
            desc
        ]
    }
    public func onLoad(cx: NSManagedObjectContext) { }
}
/// A data filler around a ``StoreDescription`` backend.
public struct BuilderStoreDescription<F, D> : StoreDescription where F: ContainerDataFiller, D: StoreDescription {
    public init(builder: F, desc: D) {
        self.builder = builder;
        self.desc = desc;
    }
    
    /// The builder to use for filling the persistent store, once loaded.
    public let builder: F;
    /// The backing to manage information.
    public let desc: D;
    
    public var modelName: String { desc.modelName }
    public var automaticLightweightMigrations: Bool { desc.automaticLightweightMigrations }
    
    public func withPersistentStores() throws -> [NSPersistentStoreDescription] {
        try desc.withPersistentStores();
    }
    public func onLoad(cx: NSManagedObjectContext) throws {
        try desc.onLoad(cx: cx);
        
        try builder.fill(context: cx);
    }
}
/// A file specific persistent store(s) for a specific model name.
public struct StandardStoreDescription : StoreDescription {
    public init(modelUrl: [URL], modelName: String, automaticLightweightMigrations: Bool) {
        self.modelUrl = modelUrl;
        self.modelName = modelName;
        self.automaticLightweightMigrations = automaticLightweightMigrations;
    }
    
    /// The file URLs to place stores.
    public let modelUrl: [URL];
    public let modelName: String;
    public let automaticLightweightMigrations: Bool;
    
    public func withPersistentStores() throws -> [NSPersistentStoreDescription] {
        modelUrl.map { NSPersistentStoreDescription(url: $0) }
    }
    public func onLoad(cx: NSManagedObjectContext) { }
}

/// An error describing a persistent store could not be loaded.
public struct ModelResolutionError : Error {
    public let name: String;
    
    public var description: String {
        "Unable to find model description named '\(name)'"
    }
}

/// A all-in-one replacement for `NSPersistentContainer` that allows for deep customization of the core data stack.
///
/// Use a ``StoreDescription`` type to manage the loading of this instance.
public final class DataStack : Sendable {
    /// Loads the stack with a specific managed object model, the stores defined by `desc`, and the main-actor bound view context.
    /// - Parameters:
    ///     - desc: The store description instruct the loading process
    /// If the managed object model described by `desc` is already known to any instance of ``DataStack``, the `NSManagedObjectModel` instance will be reused.
    public init(desc: some StoreDescription) async throws {
        let model = try Self.resolveModel(withName: desc.modelName);
        let coord = NSPersistentStoreCoordinator(managedObjectModel: model);
        
        let stores = try desc.withPersistentStores();
        print("Loading \(stores.count) stores.")
        for storeDesc in try desc.withPersistentStores() {
            try await withCheckedThrowingContinuation { [coord] (completion: CheckedContinuation<(), any Error>) in
                if desc.automaticLightweightMigrations {
                    storeDesc.shouldMigrateStoreAutomatically = true;
                    storeDesc.shouldInferMappingModelAutomatically = true;
                }
                
                coord.addPersistentStore(
                    with: storeDesc,
                    completionHandler: { returnedDesc, error in
                        if let error = error {
                            completion.resume(throwing: error);
                        }
                        
                        completion.resume();
                    }
                )
            }
        }
        
        print("All \(stores.count) stores loaded.")
        
        let cx = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType);
        cx.persistentStoreCoordinator = coord;
        await cx.perform { [cx] in
            cx.automaticallyMergesChangesFromParent = true;
            cx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        };
        await Task { @MainActor in
            let undo = UndoManager();
            await cx.perform {
                cx.undoManager = undo;
            }
        }.value;
        
        self.coordinator = coord;
        self.managedObjectModel = model;
        self.viewContext = cx;
        
        try await cx.perform { [cx] in
            try desc.onLoad(cx: cx);
        };
    }
    /// Opens a schema-less instance, with a read-only store and empty view context.
    ///
    /// This is the default value of the environment value, ``SwiftUICore/Environment/dataStack``.
    public init() {
        self.managedObjectModel = .init();
        self.coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel);
        
        let nullPath = if #available(macOS 13, *) {
            URL(filePath: "/dev/null")
        }
        else {
            URL(fileURLWithPath: "/dev/null");
        };
        
        let store = try! self.coordinator.addPersistentStore(type: .inMemory, at: nullPath);
        store.isReadOnly = true;
        
        self.viewContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType);
        self.viewContext.persistentStoreCoordinator = self.coordinator;
    }
    
    /// A coordination queue to manage ``loadedModels``.
    private static let queue: DispatchQueue = DispatchQueue(label: "DataStack");
    
    private nonisolated(unsafe) static var loadedModels: [String : NSManagedObjectModel] = [:];
    private static func resolveModel(withName: String) throws -> NSManagedObjectModel {
        return try Self.queue.asyncAndWait {
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
    }
    
    public let coordinator: NSPersistentStoreCoordinator;
    public let managedObjectModel: NSManagedObjectModel;
    public let viewContext: NSManagedObjectContext;
    
    public func newBackgroundContext() -> NSManagedObjectContext {
        let result = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType);
        result.persistentStoreCoordinator = self.coordinator;
        
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
        }
    }
}
