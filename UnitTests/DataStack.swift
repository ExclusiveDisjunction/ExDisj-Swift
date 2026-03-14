//
//  CompileTest.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/14/26.
//

import Testing
import ExDisj
@preconcurrency import CoreData

struct TemporaryDatabaseDesc : StoreDescription {
    var modelName: String { "Model" }
    var automaticLightweightMigrations: Bool { true }
    
    func withPersistentStores() throws -> [NSPersistentStoreDescription] {
        let desc = NSPersistentStoreDescription();
        
        let tmpUrl = FileManager.default.temporaryDirectory;
        
    }
    func onLoad(cx: NSManagedObjectContext) throws {
        
    }
    
    
}

@Suite("DataStack")
struct CompileTest {
    @Test("DataStackCreate")
    func testEntry() async throws {
        
    }
}
