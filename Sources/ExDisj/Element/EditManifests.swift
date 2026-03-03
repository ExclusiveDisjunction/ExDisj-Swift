//
//  EditManifests.swift
//  Edmund
//
//  Created by Hollan Sellars on 12/23/25.
//

import CoreData

public protocol EditableElementManifest {
    associatedtype Target: NSManagedObject;
    
    var target: Target { get }
    var hasChanges: Bool { get }
    var container: NSPersistentContainer { get }
    mutating func save() throws;
    mutating func reset();
}

@MainActor
public class ElementEditManifest<T> : @MainActor EditableElementManifest where T: NSManagedObject {
    public init(using: NSPersistentContainer, from: T) {
        self.cx = using.newBackgroundContext();
        self.target = cx.object(with: from.objectID) as! T;
        self.hash = self.target.hashValue;
        self.container = using;
    }
    public init?(using: NSPersistentContainer, fromId: NSManagedObjectID) {
        self.cx = using.newBackgroundContext();
        
        guard let target = cx.object(with: fromId) as? T else {
            return nil;
        }
        
        self.target = target;
        self.hash = self.target.hashValue;
        self.container = using;
    }
    
    private var hash: Int;
    private var didSave: Bool = false;
    private let cx: NSManagedObjectContext;
    public let container: NSPersistentContainer;
    public let target: T;
    
    public var hasChanges: Bool {
        self.target.hasChanges
    }
    
    public func save() throws {
        try cx.save()
        didSave = true;
        hash = target.hashValue;
    }
    public func reset() {
        cx.rollback()
        self.didSave = false;
        self.hash = target.hashValue;
    }
}

@MainActor
public class ElementAddManifest<T> : @MainActor EditableElementManifest where T: NSManagedObject {
    public init(using: NSPersistentContainer, filling: @MainActor (T) throws -> Void) rethrows {
        self.container = using;
        self.cx = using.newBackgroundContext();
        self.cx.automaticallyMergesChangesFromParent = true;
        
        let target = T(context: self.cx);
        try filling(target);
        
        self.target = target;
        self.hash = target.hashValue;
        
        self.cx.insert(self.target);
    }
    
    private var hash: Int;
    private var didSave: Bool = true;
    private let cx: NSManagedObjectContext;
    public let container: NSPersistentContainer;
    public let target: T;
    
    public var hasChanges: Bool {
        !self.didSave
    }
    
    public func save() throws {
        try cx.save()
        didSave = true;
        hash = target.hashValue;
    }
    public func reset() {
        cx.rollback()
        self.didSave = false;
        self.hash = target.hashValue;
    }
}

@MainActor
public enum ElementSelectionMode<T> where T: NSManagedObject {
    case edit(ElementEditManifest<T>)
    case add(ElementAddManifest<T>)
    case inspect(T)
    
    public var hasChanges: Bool {
        switch self {
            case .edit(let v): v.hasChanges
            case .add(let v): v.hasChanges
            case .inspect(_): false
        }
    }
    
    public static func newEdit(using: NSPersistentContainer, from: T) -> ElementSelectionMode<T> {
        return .edit(ElementEditManifest(using: using, from: from))
    }
    public static func newEdit(using: NSPersistentContainer, from: NSManagedObjectID) -> ElementSelectionMode<T>? {
        guard let manifest = ElementEditManifest<T>(using: using, fromId: from) else {
            return nil;
        }
        return .edit(manifest)
    }
    public static func newAdd(using: NSPersistentContainer, filling: @MainActor (T) throws -> Void) rethrows -> ElementSelectionMode<T> {
        return .add( try ElementAddManifest(using: using, filling: filling) )
    }
    public static func newInspect(val: T) -> ElementSelectionMode<T> {
        return .inspect(val)
    }
}
