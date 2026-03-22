//
//  DataStack.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/13/26.
//

@preconcurrency import CoreData
import CloudKit
import SwiftUI
import os

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
    /// While technically possible, `B` can be another ``BuilderStoreDescription``, but this is undefined behavior.
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
public class DataStack : @unchecked Sendable {
    /// Loads the stack with a specific managed object model, the stores defined by `desc`, and the main-actor bound view context.
    /// - Parameters:
    ///     - desc: The store description instruct the loading process
    /// If the managed object model described by `desc` is already known to any instance of ``DataStack``, the `NSManagedObjectModel` instance will be reused.
    public init(desc: some StoreDescription) async throws {
        let model = try Self.resolveModel(withName: desc.modelName);
        let coord = NSPersistentStoreCoordinator(managedObjectModel: model);
        
        let stores = try desc.withPersistentStores();
        for storeDesc in stores {
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
        
        let cx = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType);
        cx.name = "ViewContext";
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
        
        try cx.save();
    }
    /// Opens a schema-less instance, with a read-only store and empty view context.
    ///
    /// This is the default value of the environment value, ``SwiftUICore/EnvironmentValues/dataStack``.
    public init() {
        self.managedObjectModel = .init();
        self.coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel);
        
        let nullPath = if #available(macOS 13, iOS 16, *) {
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

@available(iOS 17, macOS 14, *)
public final class SyncDelegate : CKSyncEngineDelegate {
    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        
    }
    
    public func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        
    }
    
    
}

@available(iOS 17, macOS 14, *)
public final class BackgroundExecutor : SerialExecutor {
    private let queue: DispatchQueue = DispatchQueue(
        label: "BackgroundExecutor",
        qos: .utility
    );
    
    public func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job);
        queue.async {
            job.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(complexEquality: self)
    }
    
    public static let shared: BackgroundExecutor = BackgroundExecutor();
}

@available(iOS 17, macOS 14, *)
public final actor SyncStateManager {
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        BackgroundExecutor.shared.asUnownedSerialExecutor()
    }
    
    public init(log: Logger?) throws {
        var path = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true);
        path.append(path: "syncengine.state")
        log?.debug("SyncStateManager: Obtained previous sync state file path.");
        
        if let data = try? Data(contentsOf: path) {
            log?.info("SyncStateManager: Obtained contents of file, attempting to load contents.");
            state = try PropertyListDecoder().decode(CKSyncEngine.State.Serialization.self, from: data);
        }
        else {
            log?.info("SyncStateManager: No previous state could be recovered.");
            state = nil;
        }
        
        self.path = path;
        self.log = log;
    }
    
    private let log: Logger?;
    private let path: URL;
    
    public private(set) var state: CKSyncEngine.State.Serialization?;
    
    public func updateState(to: CKSyncEngine.State.Serialization) {
        do {
            let asData = try PropertyListEncoder().encode(to);
            try asData.write(to: path);
            
            self.state = to;
        }
        catch let e {
            log?.error("SyncStateManager: Unable to update the state due to error \(e.localizedDescription)")
        }
    }
    public func clearState() {
        log?.info("SyncStateManager: Deleting state file.");
        do {
            try FileManager.default.removeItem(at: path)
        }
        catch let e {
            log?.error("SyncStateManager: Unable to remove state file due to error \(e.localizedDescription)")
        }
    }
}

@available(iOS 17, macOS 14, *)
public final class CloudKitDataStack : DataStack, @unchecked Sendable {
    private init<D>(_ desc: D, subsystem: String?) async throws where D: StoreDescription {
        self.log = if let subsystem {
            Logger(subsystem: subsystem, category: "CloudKit Sync")
        }
        else {
            nil
        }
        
        let (engine, syncMan) = try await Self.buildEngine(log: log);
        self.syncEngine = engine;
        self.state = syncMan;
        
        self.cloudContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType);
        self.cloudContext.name = "CloudKitSyncContext";
        
        try await super.init(desc: desc)
        
        cloudContext.persistentStoreCoordinator = self.coordinator;
        cloudContext.undoManager = nil;
        cloudContext.automaticallyMergesChangesFromParent = true;
    }
    public convenience init(desc: StandardStoreDescription, subsystem: String?) async throws {
        try await self.init(desc, subsystem: subsystem)
    }
    public convenience init<B>(desc: StandardStoreDescription, build: B, subsystem: String?) async throws where B: ContainerDataFiller {
        try await self.init(.builder(filler: build, backing: desc), subsystem: subsystem)
    }
    
    private static func buildEngine(log: Logger?) async throws -> (CKSyncEngine, SyncStateManager) {
        let syncMan = try SyncStateManager(log: log);
        let db = try Self.openCkDatabase(log: log);
        let state = await syncMan.state;
        
        let configuration: CKSyncEngine.Configuration = .init(
            database: db,
            stateSerialization: state,
            delegate: SyncDelegate()
        );
        
        return (CKSyncEngine(configuration), syncMan)
    }
    private static func openCkDatabase(log: Logger?) throws -> CKDatabase {
        log?.info("CloudKit DataStack: Attempting to obtain cloud kit private database");
        log?.info("CloudKit DataStack: Attempting to fetch the cloud kit container identifier.");
    }
    
    private let log: Logger?;
    private let syncEngine: CKSyncEngine;
    private let state: SyncStateManager;
    private let cloudContext: NSManagedObjectContext;
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
