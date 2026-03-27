//
//  Found.swift
//  Edmund
//
//  Created by Hollan Sellars on 4/21/25.
//

import Foundation
import SwiftUI

/// Represents a common functionality between elements.
public protocol ElementBase : AnyObject, Identifiable { }

/// Represents an element that has a name.
public protocol NamedElement : AnyObject {
    /// The name of the element.
    var name: String { get set }
}

/// Represents a data type that can be inspected with a dedicated view.
public protocol InspectableElement : ElementBase {
    /// The associated view that can be used to inspect the properties of the object.
    associatedtype InspectorView: View;
    
    /// Creates a view that shows all properties of the current element.
    @MainActor
    @ViewBuilder
    func makeInspectView() -> InspectorView;
}

/// Represents a data type that can be editied with a dedicated view.
public protocol EditableElement : ElementBase {
    /// The associated view that can be used to edit the properties of the object.
    associatedtype EditView: View;
    
    /// Creates a view that shows all properties of the element, allowing for editing.
    /// This works off of the snapshot of the element, not the element itself.
    @MainActor
    @ViewBuilder
    func makeEditView() -> EditView;
}
