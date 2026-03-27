//
//  ContainerProtocol.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/27/26.
//

import SwiftData
import CoreData

public protocol ContainerProtocol {
    associatedtype Context: AnyObject;
    associatedtype SchemaDesc: AnyObject;
    
    func newContext() -> Self.Context;
}

extension NSPersistentContainer : ContainerProtocol {
    public typealias Context = NSManagedObjectContext;
    public typealias SchemaDesc = NSManagedObjectModel;
    
    public func newContext() -> NSManagedObjectContext {
        return self.newBackgroundContext()
    }
}

@available(macOS 14, iOS 17, *)
extension ModelContainer : ContainerProtocol {
    public typealias Context = ModelContext;
    public typealias SchemaDesc = Schema;
    
    public func newContext() -> ModelContext {
        return ModelContext(self)
    }
}
