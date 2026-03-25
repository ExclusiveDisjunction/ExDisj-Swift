//
//  ValueObservable.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/25/26.
//

import Observation
import SwiftUI

@available(macOS 14, iOS 17, *)
@Observable
public class ValueObservable<T> {
    public init() {
        self.action = nil;
    }
    
    public var action: T?;
    public var isActive: Bool {
        get { action != nil }
        set { action = nil }
    }
}

@available(macOS 14, iOS 17, *)
@Observable
public class TransferObservable<T> where T: Transferable {
    public init() {
        self.action = nil;
    }
    
    public var action: T?;
    public var isActive: Bool = false;
    
    public func submit(document: T) {
        self.action = document;
        self.isActive = true;
    }
}

@available(macOS 14, iOS 17, *)
fileprivate struct ValueObservableSheet<T, Body> : ViewModifier where Body: View {
    init(value: ValueObservable<T>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (T) -> Body) {
        self.value = value;
        self.onDismiss = onDismiss;
        self.innerBody = content;
    }
    
    @Bindable var value: ValueObservable<T>;
    let onDismiss: (() -> Void)?;
    let innerBody: (T) -> Body;
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $value.isActive, onDismiss: onDismiss) {
                innerBody(value.action!)
            }
    }
}

extension View {
    @available(macOS 14, iOS 17, *)
    public func sheet<T, Content>(value: ValueObservable<T>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (T) -> Content) -> some View
    where T: Copyable,
          Content: View
    {
        self
            .modifier(ValueObservableSheet(value: value, onDismiss: onDismiss, content: content))
    }
}
