//
//  EditManifests.swift
//  Edmund
//
//  Created by Hollan Sellars on 12/23/25.
//

import CoreData

/// A type that allows for the editing of a `NSManagedObject`.
public protocol EditableElementManifest {
    associatedtype Target: NSManagedObject;
    
    /// The data to edit
    var target: Target { get }
    /// If the data has changes
    var hasChanges: Bool { get }
    /// The container that `Target` comes from
    var container: DataStack { get }
    
    /// Saves the changes to ``target``
    mutating func save() throws;
    /// Resets the ``target`` to its default state.
    mutating func reset();
}

/// A manifest for editing a `NSManagedObject` value.
@MainActor
public class ElementEditManifest<T> : @MainActor EditableElementManifest where T: NSManagedObject {
    /// Opens the manifest using a specific container and a target value.
    /// - Parameters:
    ///     - using: The container that `from` is sourced.
    ///     - from: The object to edit.
    public init(using: DataStack, from: T) {
        self.cx = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType);
        self.cx.parent = using.viewContext;
        self.cx.automaticallyMergesChangesFromParent = true;
        self.cx.undoManager = using.viewContext.undoManager;
        self.cx.name = "EditManifestContext";
        
        self.target = cx.object(with: from.objectID) as! T;
        self.hash = self.target.hashValue;
        self.container = using;
    }
    /// Opens the manifest using a specific container and the ID of a target value.
    /// - Parameters:
    ///     - using: The container that `fromId` is sourced.
    ///     - fromId: The ID of the object to edit.
    /// - Warning: If  `fromId` is not a member of `using`, undefined behavior will result.
    public init?(using: DataStack, fromId: NSManagedObjectID) {
        self.cx = using.newBackgroundContext();
        self.cx.parent = using.viewContext;
        
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
    public let container: DataStack;
    public let target: T;
    
    public var hasChanges: Bool {
        self.target.hasChanges
    }
    
    public func save() throws {
        try cx.save();
        try container.viewContext.save();

        didSave = true;
        hash = target.hashValue;
    }
    public func reset() {
        cx.rollback()
        self.didSave = false;
        self.hash = target.hashValue;
    }
}

/// A manifest for adding a new `NSManagedObject` value.
@MainActor
public class ElementAddManifest<T> : @MainActor EditableElementManifest where T: NSManagedObject {
    /// Opens the manifest using a specific container and a target value.
    /// - Parameters:
    ///     - using: The container that the data will be added to.
    ///     - filling: A function that creates default values for an instance of `T`.
    public init(using: DataStack, filling: @MainActor (T) throws -> Void) rethrows {
        self.container = using;
        self.cx = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType);
        self.cx.parent = using.viewContext;
        self.cx.automaticallyMergesChangesFromParent = true;
        self.cx.undoManager = using.viewContext.undoManager;
        self.cx.name = "AddManifestContext";
        
        let target = T(context: self.cx);
        try filling(target);
        
        self.target = target;
        self.hash = target.hashValue;
        
        self.cx.insert(self.target);
    }
    
    private var hash: Int;
    private var didSave: Bool = true;
    private let cx: NSManagedObjectContext;
    public let container: DataStack;
    public let target: T;
    
    public var hasChanges: Bool {
        !self.didSave
    }
    
    public func save() throws {
        try self.cx.save();
        try container.viewContext.save();
        
        didSave = true;
        hash = target.hashValue;
    }
    public func reset() {
        cx.rollback()
        self.didSave = false;
        self.hash = target.hashValue;
    }
}

/// An overall manifest for editing, adding or inspecting `NSManagedObject` values.
@MainActor
public enum ElementSelectionMode<T> where T: NSManagedObject {
    /// The editor is opened in edit mode.
    case edit(ElementEditManifest<T>)
    /// The editor is opened in adding mode.
    case add(ElementAddManifest<T>)
    /// The editor is opened in inspecting mode.
    case inspect(T)
    
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
    public static func newEdit(using: DataStack, from: T) -> ElementSelectionMode<T> {
        return .edit(ElementEditManifest(using: using, from: from))
    }
    /// Creates a new selection for editing.
    /// - Parameters:
    ///     - using: The container that `fromId` is sourced.
    ///     - from: The ID of the object to edit.
    /// - Warning: If  `fromId` is not a member of `using`, undefined behavior will result.
    public static func newEdit(using: DataStack, from: NSManagedObjectID) -> ElementSelectionMode<T>? {
        guard let manifest = ElementEditManifest<T>(using: using, fromId: from) else {
            return nil;
        }
        return .edit(manifest)
    }
    /// Creates a new selection for adding.
    /// - Parameters:
    ///     - using: The container that the data will be added to.
    ///     - filling: A function that creates default values for an instance of `T`.
    public static func newAdd(using: DataStack, filling: @MainActor (T) throws -> Void) rethrows -> ElementSelectionMode<T> {
        return .add( try ElementAddManifest(using: using, filling: filling) )
    }
    /// Creates a new selection for inspection.
    /// - Parameters:
    ///     - val: The value to inspect.
    public static func newInspect(val: T) -> ElementSelectionMode<T> {
        return .inspect(val)
    }
}
