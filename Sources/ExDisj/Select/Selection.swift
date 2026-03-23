//
//  Selection.swift
//  Edmund
//
//  Created by Hollan Sellars on 12/25/25.
//

import SwiftUI
import CoreData

/// A context for selection based on a Core Data query.
@MainActor
@propertyWrapper
public struct QuerySelection<T> : DynamicProperty where T: NSManagedObject & Identifiable {
    public init() {
        self.init(sortDescriptors: [])
    }
    @available(macOS 12, iOS 15, *)
    public init(sortDescriptors: [SortDescriptor<T>] = [], predicate: NSPredicate? = nil, animation: Animation? = nil) {
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
