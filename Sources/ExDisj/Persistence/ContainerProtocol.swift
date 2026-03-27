//
//  ContainerProtocol.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/27/26.
//

import SwiftData
import CoreData
import SwiftUI

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

public protocol EnvAccessibleContainer : ContainerProtocol {
    static var contextKeyPath: WritableKeyPath<EnvironmentValues, Self.Context> { get }
}
extension NSPersistentContainer : EnvAccessibleContainer {
    public static var contextKeyPath: WritableKeyPath<EnvironmentValues, NSManagedObjectContext> {
        \.managedObjectContext
    }
}
