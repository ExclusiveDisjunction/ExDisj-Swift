//
//  Selection.swift
//  Edmund
//
//  Created by Hollan Sellars on 12/25/25.
//

import SwiftUI
import CoreData

/// A protocol for some type that wraps the logic for selection based filtering of data.
public protocol SelectionContextProtocol {
    associatedtype Element: Identifiable;
    
    var selectedItems: [Element] { get }
}
/// A protocol for some type that allows for a direct access to a data source and selection.
public protocol LiveSelectionContextProtocol : SelectionContextProtocol {
    associatedtype Collection: RandomAccessCollection where Collection.Element == Self.Element;
    
    var data: Collection { get }
    var selection: Binding<Set<Element.ID>> { get }
}

/// A selection that has an active, shared binding to what is currently selected.
public struct SelectionContext<C> : LiveSelectionContextProtocol where C: RandomAccessCollection, C.Element: Identifiable {
    public let data: C;
    public let selection: Binding<Set<C.Element.ID>>;
    
    public var selectedItems: [C.Element] {
        data.filter { selection.wrappedValue.contains($0.id) }
    }
    
    /// Unwraps the inner binding to keep a static selection.
    public func freeze() -> FrozenSelectionContext<C> {
        FrozenSelectionContext(data: self.data, selection: self.selection.wrappedValue)
    }
}
extension SelectionContext : Equatable where C: Equatable {
    public static func ==(lhs: SelectionContext<C>, rhs: SelectionContext<C>) -> Bool {
        lhs.data == rhs.data && lhs.selection.wrappedValue == rhs.selection.wrappedValue
    }
}
/// A selection that has a frozen storage of what is currently selected.
public struct FrozenSelectionContext<C> : SelectionContextProtocol where C: RandomAccessCollection, C.Element: Identifiable {
    public init(data: C, selection: Set<C.Element.ID>) {
        self.data = data;
        self.selection = selection;
    }
    
    public let data: C;
    public let selection: Set<C.Element.ID>;
    
    public var selectedItems: [C.Element] {
        data.filter { selection.contains($0.id) }
    }
}
extension FrozenSelectionContext : Equatable where C: Equatable {
    public static func ==(lhs: FrozenSelectionContext<C>, rhs: FrozenSelectionContext<C>) -> Bool {
        lhs.data == rhs.data && lhs.selection == rhs.selection
    }
}

/// A context for selection based on a Core Data query.
@MainActor
@propertyWrapper
public struct QuerySelection<T> : DynamicProperty where T: NSManagedObject & Identifiable {
    @available(macOS 12, iOS 15, *)
    public init(sortDescriptors: [SortDescriptor<T>] = [], predicate: NSPredicate? = nil, animation: Animation? = nil) {
        self._data = .init(sortDescriptors: sortDescriptors, predicate: predicate, animation: animation)
    }
    public init(sortDescriptors: [NSSortDescriptor] = [], predicate: NSPredicate? = nil, animation: Animation? = nil) {
        self._data = .init(sortDescriptors: sortDescriptors, predicate: predicate, animation: animation)
    }
    
    @FetchRequest private var data: FetchedResults<T>;
    @State private var selection: Set<T.ID> = .init();
    
    @available(macOS 12, iOS 15, *)
    public func configure(sortDescriptors: [NSSortDescriptor]? = nil, predicate: NSPredicate? = nil) {
        configure(predicate: predicate)
        
        if let sortDescriptors = sortDescriptors {
            self._data.projectedValue.nsSortDescriptors.wrappedValue = sortDescriptors;
        }
        
    }
    @available(macOS 12, iOS 15, *)
    public func configure(sortDescriptors: [SortDescriptor<T>]? = nil, predicate: NSPredicate? = nil) {
        self.configure(sortDescriptors: sortDescriptors?.compactMap { NSSortDescriptor($0) }, predicate: predicate)
        
    }
    @available(macOS 12, iOS 15, *)
    public func configure(predicate: NSPredicate? = nil) {
        if let predicate = predicate {
            self._data.projectedValue.nsPredicate.wrappedValue = predicate
        }
    }
    @available(macOS 12, iOS 15, *)
    public func noPredicate() {
        self._data.projectedValue.nsPredicate.wrappedValue = nil;
    }
    
    public var wrappedValue: SelectionContext<FetchedResults<T>> {
        return SelectionContext(
            data: self.data,
            selection: $selection
        )
    }
    
}

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
fileprivate class FilterableQuerySelectionContext<T> where T: NSManagedObject & Identifiable {
    init(filtering: @MainActor @escaping (T) -> Bool) {
        self.filtering = filtering;
    }
    
    var selection: Set<T.ID> = .init();
    var filteredData: [T] = [];
    var previousIds: [NSManagedObjectID] = [];
    let filtering: @MainActor (T) -> Bool;
    
    func update(data: FetchedResults<T>) {
        let currentIds = data.map( { $0.objectID } );
        
        if currentIds != self.previousIds {
            self.previousIds = currentIds;
            
            self.filteredData = data.filter(filtering)
        }
    }
}

/// A context for selection based on a Core Data query that allows for post-query filtering.
/// This allows for more advanced queries, but comes at an overhead cost.
@available(macOS 14, iOS 17, *)
@MainActor
@propertyWrapper
public struct FilterableQuerySelection<T> where T: NSManagedObject & Identifiable {
    public init(sortDescriptors: [SortDescriptor<T>] = [], predicate: NSPredicate? = nil, animation: Animation? = nil, filtering: @MainActor @escaping (T) -> Bool) {
        self._data = .init(sortDescriptors: sortDescriptors, predicate: predicate, animation: animation)
        self.context = .init(filtering: filtering)
    }
    
    @FetchRequest private var data: FetchedResults<T>;
    @Bindable private var context: FilterableQuerySelectionContext<T>;
    
    public func configure(sortDescriptors: [SortDescriptor<T>]? = nil, predicate: NSPredicate? = nil) {
        if let predicate = predicate {
            self._data.projectedValue.nsPredicate.wrappedValue = predicate;
        }
        
        if let sortDescriptors = sortDescriptors {
            self._data.projectedValue.nsSortDescriptors.wrappedValue = sortDescriptors.compactMap { NSSortDescriptor($0) };
        }
    }
    public func noPredicate() {
        self._data.projectedValue.nsPredicate.wrappedValue = nil;
    }
    
    public var wrappedValue: SelectionContext<[T]> {
        SelectionContext(
            data: context.filteredData,
            selection: $context.selection
        )
    }
}

@MainActor
@available(macOS 14, iOS 17, *)
extension FilterableQuerySelection : @MainActor DynamicProperty where T: NSManagedObject & Identifiable {
    public func update() {
        self.context.update(data: data)
    }
}

/// A context for selection based on a provided collection of data.
@propertyWrapper
public struct SourcedSelection<C> : DynamicProperty where C: RandomAccessCollection, C.Element: Identifiable {
    public init(data: C) {
        self.data = data
    }
    
    public var data: C;
    @State private var selection: Set<C.Element.ID> = .init();
    
    public var wrappedValue: SelectionContext<C> {
        SelectionContext(
            data: data,
            selection: $selection
        )
    }
}

@available(macOS 12, iOS 16, *)
public extension Table {
    /// Constructs the table around a selection context, binding the selection set and providing the data for the table.
    init<C>(
        context: C,
        @TableColumnBuilder<Value, Never> columns: () -> Columns
    ) where
        C: LiveSelectionContextProtocol,
        C.Element == Value,
        Rows == TableForEachContent<C.Collection>
    {
        self.init(context.data, selection: context.selection, columns: columns)
    }
    
    /// Constructs the table around a selection context, binding the selection set and providing the data for the table.
    init<C, Sort>(
        context: C,
        sortOrder: Binding<[Sort]>,
        @TableColumnBuilder<Value, Never> columns: () -> Columns
    ) where
        C: LiveSelectionContextProtocol,
        C.Element == Value,
        Rows == TableForEachContent<C.Collection>,
        Sort: SortComparator,
        C.Element == Sort.Compared
    {
        self.init(context.data, selection: context.selection, sortOrder: sortOrder, columns: columns)
    }
}
public extension List {
    /// Constructs the list around a selection context, binding the selection set and providing the data for the list.
    init<C, RowContent>(
        context: C,
        @ViewBuilder rowContent: @escaping (C.Element) -> RowContent
    ) where
        C: LiveSelectionContextProtocol,
        Content == ForEach<C.Collection, C.Element.ID, RowContent>,
        SelectionValue == C.Element.ID
    {
        self.init(context.data, selection: context.selection, rowContent: rowContent)
    }
}
