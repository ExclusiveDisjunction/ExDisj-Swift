//
//  ElementDisplayer.swift
//  Edmund
//
//  Created by Hollan Sellars on 8/22/25.
//

import SwiftUI

/// Displays a ``NamedElement``'s name.
public struct NamedVisualizer<T> : View where T: NamedElement {
    public let value: T?;
    
    public var body: some View {
        if let value = self.value {
            Text(value.name)
        }
        else {
            Text("(No information)")
                .italic()
        }
    }
}

/// Presents a ``Displayable`` type's UI facing value.
public struct DisplayableVisualizer<T> : View where T: Displayable {
    public init(value: T) {
        self.value = value;
    }
    
    private let value: T;
    
    public var body: some View {
        Text(value.display)
    }
}

@available(macOS 12, iOS 16, *)
extension TableColumn {
    /// Constructs a table column around a ``Displayable`` type, using the ``Displayable/display`` property. 
    @MainActor
    public init<T>(_ title: LocalizedStringKey, value: KeyPath<RowValue, T>)
    where T: Displayable,
    Label == Text,
    Sort == Never,
    Content == DisplayableVisualizer<T> {
        self.init(title, content: { rowValue in
            DisplayableVisualizer(value: rowValue[keyPath: value])
        })
    }
}


/// Displays a type titled value for a specific type. 
public struct TypeTitleVisualizer<T> : View where T: TypeTitled {
    public init(_ key: KeyPath<TypeTitleStrings, LocalizedStringKey>) {
        self.key = key;
    }
    
    private let key: KeyPath<TypeTitleStrings, LocalizedStringKey>;
    
    public var body: some View {
        Text(T.typeDisplay[keyPath: key])
            .font(.title2)
    }
}

