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
public class CDElementEditManifest<T> : ObservableObject, @MainActor EditableElementManifest where T: NSManagedObject {
    private init(target: T, container: NSPersistentContainer, context: NSManagedObjectContext) {
        self.context = context;
        self.container = container;
        self.target = target;
    }

    public let context: NSManagedObjectContext;
    public let container: NSPersistentContainer;
    @Published public private(set) var target: T;
    
    public var hasChanges: Bool {
        self.target.hasChanges
    }
    
    public func save() throws {
        try context.save();
        try container.viewContext.save();
    }
    public func reset() {
        context.rollback()
    }
}

/// A manifest for editing a `NSManagedObject` value.
@available(macOS 14, iOS 17, *)
@Observable
@MainActor
public class SDElementEditManifest<T> : @MainActor EditableElementManifest where T: PersistentModel {
    private init(target: T, container: SwiftDataStack, context: ModelContext) {
        self.context = context;
        self.container = container;
        self.target = target;
    }
    
    @ObservationIgnored public let context: ModelContext;
    @ObservationIgnored public let container: SwiftDataStack;
    public private(set) var target: T;
    
    public var hasChanges: Bool {
        self.target.hasChanges
    }
    
    public func save() throws {
        try context.save();
        try container.mainContext.save()
    }
    public func reset() {
        context.rollback()
    }
}

@MainActor
public class CDElementAddManifest<T> : ObservableObject, @MainActor EditableElementManifest where T: NSManagedObject {
    private init(target: T, container: NSPersistentContainer, context: NSManagedObjectContext) {
        didSave = false;
        self.context = context;
        self.container = container;
        self.target = target;
    }
    
    private var didSave: Bool = true;
    public let context: NSManagedObjectContext;
    public let container: NSPersistentContainer;
    @Published public private(set) var target: T;
    
    public var hasChanges: Bool {
        !self.didSave
    }
    public func save() throws {
        try self.context.save();
        try container.viewContext.save();
        
        didSave = true;
    }
    public func reset() {
        context.rollback()
        self.didSave = false;
    }
}

@available(macOS 14, iOS 17, *)
@Observable
@MainActor
public class SDElementAddManifest<T> : @MainActor EditableElementManifest where T: NSManagedObject {
    private init(target: T, container: NSPersistentContainer, context: NSManagedObjectContext) {
        didSave = false;
        self.context = context;
        self.container = container;
        self.target = target;
    }
    
    @ObservationIgnored private var didSave: Bool = true;
    @ObservationIgnored public let context: NSManagedObjectContext;
    @ObservationIgnored public let container: NSPersistentContainer;
    public private(set) var target: T;
    
    public var hasChanges: Bool {
        !self.didSave
    }
    public func save() throws {
        try self.context.save();
        try container.viewContext.save();
        
        didSave = true;
    }
    public func reset() {
        context.rollback()
        self.didSave = false;
    }
}

/// An overall manifest for editing, adding or inspecting `NSManagedObject` values.
@MainActor
public enum ElementSelectionMode<T, MAdd, MEdit>
where MAdd: EditableElementManifest,
      MEdit: EditableElementManifest,
      MAdd.Target == T,
      MEdit.Target == T,
      MAdd.Container == MEdit.Container
{
    /// The editor is opened in edit mode.
    case edit(MEdit)
    /// The editor is opened in adding mode.
    case add(MAdd)
    /// The editor is opened in inspecting mode.
    case inspect(T)
    
    /// Creates a new selection for inspection.
    /// - Parameters:
    ///     - val: The value to inspect.
    public static func newInspect(val: T) -> Self {
        return .inspect(val)
    }
}

extension ElementSelectionMode
where T: NSManagedObject,
      MAdd == CDElementAddManifest<T>,
      MEdit == CDElementEditManifest<T>
{
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
        return .edit(CDElementEditManifest(target: from, container: using, context: <#T##NSManagedObjectContext#>)
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
extension ElementSelectionMode
where T: PersistentModel,
      MAdd == SDElementAddManifest<T>,
      MEdit == SDElementEditManifest<T>
{
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
