//
//  FilterSubsection.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/3/26.
//

import SwiftUI

/// A SwftUI `Section` that allows for the modification of a `Set<T>` through toggles.
public struct FilterSubsection<C, T> : View
where C: AnyObject,
      T: Hashable & Identifiable & Displayable & CaseIterable,
      T.AllCases: RandomAccessCollection {
    
    public init(_ name: LocalizedStringKey, source: C, path: WritableKeyPath<C, Set<T>>) {
        self.name = name;
        self.source = source;
        self.path = path;
    }
    
    let name: LocalizedStringKey;
    let source: C;
    let path: WritableKeyPath<C, Set<T>>;
    
    func bind(val: T) -> Binding<Bool> {
        Binding(
            get: {
                source[keyPath: path].contains(val)
            },
            set: { [source] newValue in
                var source = source;
                
                if newValue {
                    source[keyPath: path].insert(val)
                }
                else {
                    source[keyPath: path].remove(val)
                }
            }
        )
    }
    
    public var body: some View {
        Section {
            ForEach(T.allCases) { value in
                Toggle(value.display, isOn: bind(val: value))
            }
        } header: {
            HStack {
                Text(name)
                
                Divider()
                
                Button("Select All") { [source] in
                    var source = source;
                    
                    source[keyPath: path] = Set(T.allCases)
                }.buttonStyle(.borderless)
                Button("Deselect All") { [source] in
                    var source = source;
                    
                    source[keyPath: path] = Set()
                }.buttonStyle(.borderless)
            }
        }
    }
}
