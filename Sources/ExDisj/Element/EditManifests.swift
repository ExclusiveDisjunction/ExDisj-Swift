//
//  EditManifests.swift
//  Edmund
//
//  Created by Hollan Sellars on 12/23/25.
//

import CoreData
import SwiftData


/// A type that allows for the editing of a `NSManagedObject`.
public protocol EditableElementManifest {
    associatedtype Container: ContainerProtocol;
    associatedtype Target: AnyObject;
    
    /// The data to edit
    var target: Target { get }
    /// If the data has changes
    var hasChanges: Bool { get }
    /// The container that `Target` comes from
    var container: Container { get }
    var context: Container.Context { get }
    
    /// Saves the changes to ``target``
    mutating func save() throws;
    /// Resets the ``target`` to its default state.
    mutating func reset();
}

/// A manifest for editing a `NSManagedObject` value.
@MainActor
public class ElementEditManifest<T, Container> where Container: ContainerProtocol, T: AnyObject & Hashable {
    private init(target: T, container: Container, context: Container.Context) {
        hash = target.hashValue;
        didSave = false;
        self.context = context;
        self.container = container;
        self.target = target;
    }
    
    private var hash: Int;
    private var didSave: Bool = false;
    public let context: Container.Context;
    public let container: Container;
    public let target: T;
}
extension ElementEditManifest : @MainActor EditableElementManifest where Container == NSPersistentContainer, T: NSManagedObject {
    /// Opens the manifest using a specific container and a target value.
    /// - Parameters:
    ///     - using: The container that `from` is sourced.
    ///     - from: The object to edit.
    public convenience init(using: NSPersistentContainer, from: T) {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType);
        context.parent = using.viewContext;
        context.automaticallyMergesChangesFromParent = true;
        context.undoManager = using.viewContext.undoManager;
        context.name = "EditManifestContext";
        
        self.init(
            target: context.object(with: from.objectID) as! T,
            container: using,
            context: context
        );
    }
    
    public var hasChanges: Bool {
        self.target.hasChanges
    }
    
    public func save() throws {
        try context.save();
        try container.viewContext.save();
        
        didSave = true;
        hash = target.hashValue;
    }
    public func reset() {
        context.rollback()
        self.didSave = false;
        self.hash = target.hashValue;
    }
}
@available(macOS 14, iOS 17, *)
extension ElementEditManifest : @MainActor EditableElementManifest where Container == SwiftDataStack, T: PersistentModel {
    public convenience init(using: SwiftDataStack, from: T) {
        let context = ModelContext(using.container);
        context.autosaveEnabled = false;
        context.undoManager = using.mainContext.undoManager;
        
        self.init(
            target: context.model(for: from.persistentModelID) as! T,
            container: using,
            context: context
        );
    }
    
    public var hasChanges: Bool {
        self.target.hasChanges
    }
    
    public func save() throws {
        try context.save();
        try container.mainContext.save()
        
        didSave = true;
        hash = target.hashValue;
    }
    public func reset() {
        context.rollback()
        self.didSave = false;
        self.hash = target.hashValue;
    }
}

/// A manifest for adding a new `NSManagedObject` value.
@MainActor
public class ElementAddManifest<T, Container> where Container: ContainerProtocol, T: AnyObject & Hashable {
    private init(target: T, container: Container, context: Container.Context) {
        hash = target.hashValue;
        didSave = false;
        self.context = context;
        self.container = container;
        self.target = target;
    }
    
    private var hash: Int;
    private var didSave: Bool = true;
    public let context: Container.Context;
    public let container: Container;
    public let target: T;
    
    public var hasChanges: Bool {
        !self.didSave
    }
}
extension ElementAddManifest : @MainActor EditableElementManifest where Container == NSPersistentContainer, T: NSManagedObject {
    /// Opens the manifest using a specific container and a target value.
    /// - Parameters:
    ///     - using: The container that the data will be added to.
    ///     - filling: A function that creates default values for an instance of `T`.
    public convenience init(using: NSPersistentContainer, filling: @MainActor (T, NSManagedObjectContext) throws -> Void) rethrows {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType);
        context.parent = using.viewContext;
        context.automaticallyMergesChangesFromParent = true;
        context.undoManager = using.viewContext.undoManager;
        context.name = "AddManifestContext";
        
        let target = T(context: context);
        try filling(target, context);
        context.insert(target);
        
        self.init(
            target: target,
            container: using,
            context: context
        );
    }
    
    public func save() throws {
        try self.context.save();
        try container.viewContext.save();
        
        didSave = true;
        hash = target.hashValue;
    }
    public func reset() {
        context.rollback()
        self.didSave = false;
        self.hash = target.hashValue;
    }
}
@available(macOS 14, iOS 17, *)
extension ElementAddManifest : @MainActor EditableElementManifest where Container == SwiftDataStack, T: PersistentModel {
    public convenience init(using: SwiftDataStack, filling: @MainActor (ModelContext) throws -> T) rethrows {
        let context = ModelContext(using.container);
        context.autosaveEnabled = false;
        context.undoManager = using.mainContext.undoManager;
        
        let target = try filling(context);
        context.insert(target);
        
        self.init(
            target: target,
            container: using,
            context: context
        )
    }
}

/// An overall manifest for editing, adding or inspecting `NSManagedObject` values.
@MainActor
public enum ElementSelectionMode<T, Container> where Container: ContainerProtocol, T: AnyObject & Hashable {
    /// The editor is opened in edit mode.
    case edit(ElementEditManifest<T, Container>)
    /// The editor is opened in adding mode.
    case add(ElementAddManifest<T, Container>)
    /// The editor is opened in inspecting mode.
    case inspect(T)
    
    /// Creates a new selection for inspection.
    /// - Parameters:
    ///     - val: The value to inspect.
    public static func newInspect(val: T) -> Self {
        return .inspect(val)
    }
}

extension ElementSelectionMode where Container == NSPersistentContainer, T: NSManagedObject {
    /// Determines if there are pending changes to be saved.
    public var hasChanges: Bool {
        switch self {
            case .edit(let v): v.hasChanges
            case .add(let v): v.hasChanges
            case .inspect(_): false
        }
    }
    
    /// Creates a new selection for editing.
    /// - Parameters:
    ///     - using: The container that `from` is sourced.
    ///     - from: The object to edit.
    public static func newEdit(using: NSPersistentContainer, from: T) -> Self {
        return .edit(ElementEditManifest(using: using, from: from))
    }
    /// Creates a new selection for adding.
    /// - Parameters:
    ///     - using: The container that the data will be added to.
    ///     - filling: A function that creates default values for an instance of `T`.
    public static func newAdd(using: DataStack, filling: @MainActor (T, NSManagedObjectContext) throws -> Void) rethrows -> Self {
        return .add( try ElementAddManifest(using: using, filling: filling) )
    }
}

@available(macOS 14, iOS 17, *)
extension ElementSelectionMode where Container == SwiftDataStack, T: PersistentModel {
    /// Determines if there are pending changes to be saved.
    public var hasChanges: Bool {
        switch self {
            case .edit(let v): v.hasChanges
            case .add(let v): v.hasChanges
            case .inspect(_): false
        }
    }
    
    /// Creates a new selection for editing.
    /// - Parameters:
    ///     - using: The container that `from` is sourced.
    ///     - from: The object to edit.
    public static func newEdit(using: SwiftDataStack, from: T) -> Self {
        return .edit(ElementEditManifest(using: using, from: from))
    }
    /// Creates a new selection for adding.
    /// - Parameters:
    ///     - using: The container that the data will be added to.
    ///     - filling: A function that creates default values for an instance of `T`.
    public static func newAdd(using: SwiftDataStack, filling: @MainActor (ModelContext) throws -> T) rethrows -> Self {
        return .add( try ElementAddManifest(using: using, filling: filling) )
    }
    
}
