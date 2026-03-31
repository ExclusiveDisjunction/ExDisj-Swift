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
    public final class Token : Sendable {
        fileprivate init(name: String, model: NSManagedObjectModel) {
            self.name = name;
            self.model = model;
        }
        
        public let name: String;
        public let model: NSManagedObjectModel;
        
        deinit {
            CoreDataSchemaManager.dropSchemaCount(withName: self.name);
        }
    }
    private final class LoadedModel : @unchecked Sendable {
        fileprivate init(_ model: NSManagedObjectModel, keepAlive: Bool) {
            self.model = model;
            self.refCount = 1;
            self.keepAlive = keepAlive;
        }
        
        public let model: NSManagedObjectModel;
        fileprivate var refCount: Int = 1;
        fileprivate let keepAlive: Bool;
    }
    
    fileprivate static func dropSchemaCount(withName: String) {
        Self.queue.async { [withName] in
            guard let model = Self.loadedModels[withName] else {
                return;
            }
            
            model.refCount -= 1;
            if model.refCount <= 0 && !model.keepAlive { //Removes it from static memory if no longer needed.
                loadedModels.removeValue(forKey: withName);
            }
        }
    }
    
    /// A coordination queue to manage ``loadedModels``.
    private static let queue: DispatchQueue = DispatchQueue(label: "DataStack");
    
    private nonisolated(unsafe) static var loadedModels: [String : LoadedModel] = [:];
    
    private static func resolveModelOnQueue(withName: String, keepAlive: Bool) throws -> Self.Token {
        if let model = Self.loadedModels[withName] {
            model.refCount += 1;
            let token = Self.Token(name: withName, model: model.model);
            
            return token;
        }
        
        guard let url = Bundle.main.url(forResource: withName, withExtension: "momd") else {
            throw ModelResolutionError(name: withName);
        }
        
        guard let model = NSManagedObjectModel(contentsOf: url) else {
            throw ModelResolutionError(name: withName);
        }
        
        Self.loadedModels[withName] = Self.LoadedModel(model, keepAlive: keepAlive);
        let token = Self.Token(name: withName, model: model);
        return token;
    }
    
    public static func resolveModel(withName: String, keepAlive: Bool = false) async throws -> Self.Token {
        
        return try await withCheckedThrowingContinuation { cont in
            do {
                let result = try Self.queue.asyncAndWait {
                    try resolveModelOnQueue(withName: withName, keepAlive: keepAlive);
                }
                
                cont.resume(returning: result)
            }
            catch let e {
                cont.resume(throwing: e)
            }
        }
    }
    
    public static let nullModelName: String = "!NULL!";
    public static var nullModel: Self.Token {
        get {
            return Self.queue.asyncAndWait {
                if let model = Self.loadedModels[Self.nullModelName] {
                    model.refCount += 1;
                    let token = Self.Token(name: nullModelName, model: model.model);
                    
                    return token;
                }
                
                let model = NSManagedObjectModel();
                Self.loadedModels[Self.nullModelName] = Self.LoadedModel(model, keepAlive: false);
                
                let token = Self.Token(name: nullModelName, model: model);
                return token;
            }
        }
    }
}

/*
public struct ModelVersion : Sendable, Equatable, Hashable, CustomStringConvertible {
    public let major: Int;
    public let minor: Int;
    
    public var description: String {
        "\(major).\(minor)"
    }
}

public enum MigrationType : Sendable, Equatable {
    public struct Manual : Sendable, Equatable {
        
    }
    
    case automatic
    case manual(Manual)
}

public struct SchemaVersion : Sendable, Equatable {
    public let modelsName: String;
    public let version: ModelVersion;
}

public struct MigrationStage : Sendable, Equatable {
    
    public let migrationType: MigrationType;
    public let targetVersion: SchemaVersion;
}

public struct MigrationsManager : Sendable {
    public let baseVersion: SchemaVersion;
    public let stages: [MigrationStage]
}
*/ //For a later day

public struct ContainerDescription : Sendable {
    public typealias LoadAction = @Sendable (NSManagedObjectContext) throws -> Void;
    
    public let schemaName: String;
    public let stores: [StoreDescription];
    public let onLoad: LoadAction?;
    
    public static func inMemory(schemaName: String, readOnly: Bool = false, onLoad: LoadAction? = nil) -> ContainerDescription {
        return ContainerDescription(
            schemaName: schemaName,
            stores: [
                .init(storeType: .inMemory, isReadOnly: readOnly, automaticMigrations: true)
            ],
            onLoad: onLoad
        )
    }
    public static func inMemory<F>(schemaName: String, filler: F, onLoad: LoadAction? = nil) -> ContainerDescription
    where F: ContainerDataFiller
    {
        return ContainerDescription(
            schemaName: schemaName,
            stores: [
                .init(storeType: .inMemory, isReadOnly: false, automaticMigrations: true)
            ],
            onLoad: { context in
                try filler.fill(context: context);
                
                if let onLoad {
                    try onLoad(context)
                }
            }
        )
    }
    
    public static func onDisk(schemaName: String, fileUrl: URL, readOnly: Bool = false, automaticallyMigrate: Bool = true, onLoad: LoadAction? = nil) -> ContainerDescription {
        return ContainerDescription(
            schemaName: schemaName,
            stores: [
                .init(storeType: .inFile(fileUrl), isReadOnly: readOnly, automaticMigrations: automaticallyMigrate)
            ],
            onLoad: onLoad
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
    public init(desc: ContainerDescription) async throws {
        self.modelToken = try await CoreDataSchemaManager.resolveModel(withName: desc.schemaName);
        super.init(name: "DataStack", managedObjectModel: modelToken.model);
        
        self.persistentStoreDescriptions = desc.stores.map {
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
        self.modelToken = CoreDataSchemaManager.nullModel;
        super.init(name: "NullModel", managedObjectModel: modelToken.model)
        
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
    
    public let modelToken: CoreDataSchemaManager.Token;
    
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
