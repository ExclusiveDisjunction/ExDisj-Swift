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

public enum PersistentStoreKind : Sendable, Equatable, Hashable, Codable {
    case inMemory
    case file(URL)
    
    public static var nullUrl: URL {
        if #available(macOS 13, iOS 16, *) {
            return URL(filePath: "/dev/null")
        }
        else {
            return URL(fileURLWithPath: "/dev/null");
        };
    }
    
    public var url: URL {
        switch self {
            case .inMemory: Self.nullUrl
            case .file(let v): v
        }
    }
}
public struct PersistentStoreConfiguration : Sendable, Equatable, Hashable, Codable {
    public init(kind: PersistentStoreKind, isReadOnly: Bool = false, inferMappingModel: Bool = true) {
        self.kind = kind
        self.isReadOnly = isReadOnly
        self.inferMappingModel = inferMappingModel;
    }
    
    public static let inMemory: PersistentStoreConfiguration = .init(kind: .inMemory);
    public static func fromFile(url: URL, isReadOnly: Bool = false, inferMappingModel: Bool = true) -> PersistentStoreConfiguration {
        return self.init(kind: .file(url), isReadOnly: isReadOnly, inferMappingModel: inferMappingModel)
    }
    
    public let kind: PersistentStoreKind;
    public let isReadOnly: Bool;
    public let inferMappingModel: Bool;
    
    public func complete() -> NSPersistentStoreDescription {
        let desc = NSPersistentStoreDescription();
        desc.url = kind.url;
        desc.type = NSSQLiteStoreType;
        desc.shouldAddStoreAsynchronously = false;
        desc.shouldInferMappingModelAutomatically = self.inferMappingModel;
        desc.shouldMigrateStoreAutomatically = false;
        desc.isReadOnly = isReadOnly;
        
        return desc;
    }
}

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
    
    /// Returns the persistent stores associated with this description.
    func configurations() throws -> [PersistentStoreConfiguration];
    
    /// After the stack has been loaded, an optional closure to perform.
    /// - Parameters:
    ///     - cx: The object context to modify once loaded.
    /// - Warning: This call is made within a `perform` block. Do not call `cx.performAndWait`, as a deadlock will occur.
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
    
    public func configurations() -> [PersistentStoreConfiguration] {
        return [
            .inMemory
        ]
    }
    public func onLoad(cx: NSManagedObjectContext) { }
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
    
    public func configurations() -> [PersistentStoreConfiguration] {
        modelUrl.map { .fromFile(url: $0, inferMappingModel: automaticLightweightMigrations) }
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
    
    public func configurations() throws -> [PersistentStoreConfiguration] {
        try desc.configurations();
    }
    public func onLoad(cx: NSManagedObjectContext) throws {
        try desc.onLoad(cx: cx);
        
        try builder.fill(context: cx);
    }
}


/// An error describing a persistent store could not be loaded.
public struct ModelResolutionError : Error {
    public let name: String;
    
    public var description: String {
        "Unable to find model description named '\(name)'"
    }
}

public struct ManagedObjectModelResolver : Sendable {
    /// A coordination queue to manage ``loadedModels``.
    private static let queue: DispatchQueue = DispatchQueue(label: "DataStack", qos: .utility);
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

/// A all-in-one replacement for `NSPersistentContainer` that allows for deep customization of the core data stack.
///
/// Use a ``StoreDescription`` type to manage the loading of this instance.
public class DataStack : NSPersistentContainer, @unchecked Sendable {
    /// Loads the stack with a specific managed object model, the stores defined by `desc`, and the main-actor bound view context.
    /// - Parameters:
    ///     - desc: The store description instruct the loading process
    /// If the managed object model described by `desc` is already known to any instance of ``DataStack``, the `NSManagedObjectModel` instance will be reused.
    public init(desc: some StoreDescription) async throws {
        let model = try await ManagedObjectModelResolver.resolveModel(withName: desc.modelName);
        super.init(name: desc.modelName, managedObjectModel: model);
        
        self.persistentStoreDescriptions = try desc.configurations().map { $0.complete() };
        
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
            
            try desc.onLoad(cx: viewContext)
            try viewContext.save();
        }
    }
    /// Opens a schema-less instance, with a read-only store and empty view context.
    ///
    /// This is the default value of the environment value, ``SwiftUICore/EnvironmentValues/dataStack``.
    public init() {
        let nullModel = ManagedObjectModelResolver.nullModel;
        super.init(name: "NullModel", managedObjectModel: nullModel)
        
        self.persistentStoreDescriptions = [
            PersistentStoreConfiguration(kind: .inMemory, isReadOnly: true)
                .complete()
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

public final class CloudKitDataStack : NSPersistentCloudKitContainer, @unchecked Sendable {
    
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
