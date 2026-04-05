//
//  AccountPicker.swift
//  Edmund
//
//  Created by Hollan on 1/14/25.
//

import SwiftUI
import CoreData

/// A `Picker` from SwiftUI specifically for picking a `NSManagedObject` type.
public struct ElementPicker<T> : View where T: Identifiable & NamedElement & NSManagedObject {
    /// Constructs the picker with a binding to a `T` value.
    /// - Parameters:
    ///     - target: The resulting location to store the picked element.
    ///     - withSorting: The sort descriptors to use for presenting the information
    ///     - withPredicate: The predicate to use for presenting the information
    ///     - onNil: The string to present when no selection is made.
    @available(macOS 14, iOS 17, *)
    public init(
        _ target: Binding<T?>,
        withSorting: [SortDescriptor<T>] = [],
        withPredicate: NSPredicate? = nil,
        onNil: String = "-"
    ) {
        self._target = target
        self.onNil = onNil;
        self._choices = FetchRequest(sortDescriptors: withSorting, predicate: withPredicate)
    }
    
    /// Constructs the picker with a binding to a `T` value.
    /// - Parameters:
    ///     - target: The resulting location to store the picked element.
    ///     - withSorting: The sort descriptors to use for presenting the information
    ///     - withPredicate: The predicate to use for presenting the information
    ///     - onNil: The string to present when no selection is made.
    public init(
        _ target: Binding<T?>,
        withSorting: [NSSortDescriptor] = [],
        withPredicate: NSPredicate? = nil,
        onNil: String = "-"
    ) {
        self._target = target
        self.onNil = onNil;
        self._choices = FetchRequest(sortDescriptors: withSorting, predicate: withPredicate)
    }
    
    @FetchRequest private var choices: FetchedResults<T>;
    
    @Binding private var target: T?;
    @State private var id: T.ID?;
    private let onNil: String;
    
    private func idChanged(_ newId: T.ID?) {
        guard let id = newId else {
            self.target = nil;
            return;
        }
        
        self.target = choices.first(where: { $0.id == id } )
    }
    
    @ViewBuilder
    private var picker: some View {
        Picker("", selection: $id) {
            Text(onNil)
                .italic()
                .tag(nil as T.ID?)
            
            ForEach(choices) { choice in
                Text(choice.name)
                    .tag(choice.id)
            }
        }.labelsHidden()
    }
    
    public var body: some View {
        if #available(iOS 17, macOS 14, *) {
            picker.onChange(of: id) { _, newId in
                idChanged(newId)
            }
        }
        else {
            picker.onChange(of: id, perform: idChanged)
        }
    }
}

/// A `Picker` from SwiftUI  for ``Displayable`` enumerations.
public struct EnumPicker<T> : View where T: CaseIterable & Identifiable & Displayable, T.AllCases: RandomAccessCollection, T.ID == T {
    /// Accepts a binding to the target value.
    @preconcurrency public init(_ key: String, value: Binding<T>) {
        self._value = value;
        self.key = key;
    }
    
    @Binding private var value: T;
    private let key: String;
    
    public var body: some View {
        Picker(key, selection: $value) {
            ForEach(T.allCases) { element in
                Text(element.display).tag(element)
            }
        }.menuStyle(.automatic)
    }
}
