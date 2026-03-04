//
//  Context.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/4/26.
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
