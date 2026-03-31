//
//  StoreDescription.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/27/26.
//

import CoreData
import SwiftData
import Foundation

public struct StoreDescription : Sendable {
    public enum StoreType : Sendable {
        case inMemory
        case inFile(URL)
        
        public var url: URL {
            switch self {
                case .inMemory:
                    return URL(fileURLWithPath: "/dev/null")
                case .inFile(let url):
                    return url
            }
        }
    }
    
    public let storeType: StoreType;
    public let isReadOnly: Bool;
    public let automaticMigrations: Bool;
    
    public func makePersistentContainerDescription() -> NSPersistentStoreDescription {
        let result = NSPersistentStoreDescription();
        
        result.url = self.storeType.url;
        result.type = NSSQLiteStoreType;
        result.shouldAddStoreAsynchronously = false;
        result.shouldMigrateStoreAutomatically = self.automaticMigrations;
        result.shouldInferMappingModelAutomatically = self.automaticMigrations;
        result.isReadOnly = self.isReadOnly;
        
        return result;
    }
    
    @available(macOS 14, iOS 17, *)
    public func makeContainerConfiguration(withSchema schema: Schema?) -> ModelConfiguration {
        switch self.storeType {
            case .inMemory:
                return ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    allowsSave: !self.isReadOnly,
                    groupContainer: .none,
                    cloudKitDatabase: .none
                )
            case .inFile(let url):
                return ModelConfiguration(
                    schema: schema,
                    url: url,
                    allowsSave: !self.isReadOnly,
                    cloudKitDatabase: .none
                )
        }
    }
}
