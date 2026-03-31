//
//  SwiftDataStack.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/27/26.
//

import SwiftData
import Foundation
import SwiftUI

@available(macOS 14, iOS 17, *)
extension ContainerDescription where Container == SwiftDataStack {
    public static func inMemory(
        schema: Schema,
        onLoad: (@Sendable (ModelContext) throws -> Void)? = nil
    ) -> Self {
        self.init(
            schemaLocator: {
                return schema
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
        schema: Schema,
        withBuilder: B,
        onLoad: (@Sendable (ModelContext) throws -> Void)? = nil
    ) -> Self where B: ContainerDataFiller, B.Container == Container {
        self.init(
            schemaLocator: {
                return schema
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
    
    public static func onDiskDefault(
        schema: Schema,
        onLoad: (@Sendable (ModelContext) throws -> Void)? = nil
    ) -> Self {
        self.init(
            schemaLocator: {
                return schema
            },
            stores: {
                return []
            },
            onLoad: onLoad
        )
    }
    public static func onDisk(
        schema: Schema,
        url: URL,
        onLoad: (@Sendable (ModelContext) throws -> Void)? = nil
    ) -> Self {
        self.init(
            schemaLocator: {
                return schema
            },
            stores: {
                return [
                    .init(storeType: .inFile(url), isReadOnly: false, automaticMigrations: true)
                ]
            },
            onLoad: onLoad
        )
    }
}

@available(macOS 14, iOS 17, *)
public final class SwiftDataStack : Sendable, ContainerProtocol {
    public typealias Context = ModelContext;
    public typealias SchemaDesc = Schema;
    
    public init(desc: ContainerDescription<SwiftDataStack>) async throws {
        let schema = try await desc.schemaLocator();
        
        let configurations = try desc.stores();
        if configurations.isEmpty {
            container = try ModelContainer(for: schema, migrationPlan: nil);
        }
        else {
            container = try ModelContainer(for: schema, migrationPlan: nil, configurations: configurations.map { $0.makeContainerConfiguration(withSchema: schema) } );
        }
    }
    public init() {
        do {
            container = try ModelContainer(for: Schema(), configurations: [])
        }
        catch let e {
            fatalError("SwiftDataStack: Unable to create empty container, error: \(e)");
        }
    }
    
    public let container: ModelContainer;
    @MainActor
    public var mainContext: ModelContext {
        get { container.mainContext }
    }
    
    public func newContext() -> ModelContext {
        return ModelContext(self.container)
    }
}

@available(macOS 14, iOS 17, *)
fileprivate struct SwiftDataStackEnvKey : EnvironmentKey {
    typealias Value = SwiftDataStack;
    static var defaultValue: SwiftDataStack {
        return .init();
    }
}

public extension EnvironmentValues {
    @MainActor
    @available(macOS 14, iOS 17, *)
    var swiftDataStack: SwiftDataStack {
        get { self[SwiftDataStackEnvKey.self] }
        set {
            self[SwiftDataStackEnvKey.self] = newValue;
            self.modelContext = newValue.mainContext;
            newValue.mainContext.undoManager = self.undoManager;
        }
    }
}

@available(macOS 14, iOS 17, *)
extension SwiftDataStack : EnvAccessibleContainer {
    public static var contextKeyPath: WritableKeyPath<EnvironmentValues, ModelContext> {
        \.modelContext
    }
}
