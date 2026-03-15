//
//  Warnings.swift
//  Edmund
//
//  Created by Hollan Sellars on 4/1/25.
//

import SwiftUI

/// A simplified, general view to place inside of a `ContextMenu`. it provides shortcuts to view (if allowed), edit, and delete objects. Optionally, it provides a shortcut for adding objects.
@available(macOS 14, iOS 17, *)
public struct SingularContextMenu<T> : View where T: Identifiable {
    /// The object that the menu is for.
    private var target: T;
    /// A manifest showing the view/edit mode of the selected object.
    private var inspection: InspectionManifest<T>;
    /// The deleting action used to store the information that can be deleted.
    private var delete: DeletingManifest<T>;
    /// Signifies that the context menu allows for view inspection
    private let canInspect: Bool;
    /// Signals that the view uses the Slide style.
    private let asSlide: Bool;
    
    /// Constructs a context menu based on the provided information.
    /// - Parameters:
    ///     - target: The element to modify
    ///     - inspect: The `InspectionManifest<T>` used to signal to the parent view that an inspection/edit should take place.
    ///     - remove: The `DeletingManifest<T>` used to signal to the parent view that the element is being removed.
    ///     - canInspect: If the `target` can be inspected or not.
    ///     - asSlide: When true, the menu will be presented as a slide menu, with tinted colors.
    public init(_ target: T, inspect: InspectionManifest<T>, remove: DeletingManifest<T>, canInspect: Bool = true, asSlide: Bool) {
        self.target = target
        self.inspection = inspect
        self.canInspect = canInspect
        self.delete = remove
        self.asSlide = asSlide
    }
    
    public var body: some View {
        if canInspect {
            Button {
                inspection.open(value: target, editing: false)
            } label: {
                Image(systemName: "info.circle")
            }.tint(asSlide ? .green : .clear)
                .accessibilityLabel("Inspect Current")
                .accessibilityHint("Opens the current data for close look to view all properties")
        }
        
        Button {
            inspection.open(value: target, editing: true)
        } label: {
            Image(systemName: "pencil")
        }.tint(asSlide ? .blue : .clear)
            .accessibilityLabel("Edit Current")
            .accessibilityHint("Opens the current data for editing of all properties")
        
        Button {
            delete.action = [target]
        } label: {
            Image(systemName: "trash").foregroundStyle(.red)
        }.tint(asSlide ? .red : .clear)
            .accessibilityLabel("Delete Current")
            .accessibilityHint("Deletes the current data")
    }
}

/// A generalized context menu that runs for `.contextMenu(forSelectionType: T.ID)`.
@available(macOS 14, iOS 17, *)
public struct SelectionContextMenu<W> : View where W: SelectionContextProtocol {
    /// A handle for viewing/editing
    private let inspect: InspectionManifest<W.Element>;
    /// A handle for deleting objects.
    private let delete: DeletingManifest<W.Element>;
    /// The warning manifest used for alerting about errors.
    private let warning: SelectionWarningManifest;
    /// The context used by the menu.
    private let context: W;
    /// When true, the  "Inspect" menu option is provided.
    private let canView: Bool;
    /// True when the selected context has exactly one selected item.
    private let inspectEnabled: Bool;
    
    /// Constructs a context menu based on the provided information.
    /// - Parameters:
    ///     - context: The selection context to source information from.
    ///     - inspect: The `InspectionManifest<T>` used to signal to the parent view that an inspection/edit should take place.
    ///     - delete: The `DeletingManifest<T>` used to signal to the parent view that the element is being removed.
    ///     - warning: The `WarningManifest` used to signal to the parent view that something is wrong.
    ///     - canView: When true, inspection is allowed.
    public init(context: W, inspect: InspectionManifest<W.Element>, delete: DeletingManifest<W.Element>, warning: SelectionWarningManifest, canView: Bool = true) {
        self.context = context;
        self.inspect = inspect
        self.delete = delete
        self.warning = warning
        self.canView = canView
        self.inspectEnabled = context.selectedItems.count == 1;
    }
    
    private func handleEdit() {
        inspect.open(selection: self.context, editing: true, warning: warning)
    }
    private func handleView() {
        inspect.open(selection: self.context, editing: false, warning: warning)
    }
    private func handleDelete() {
        delete.delete(self.context, warning: warning)
    }
    
    public var body: some View {
        if canView {
            Button(action: handleView ) {
                Label("Inspect", systemImage: "info.circle")
            }.disabled(!inspectEnabled)
                .accessibilityLabel("Inspect Selected")
                .accessibilityHint("If only one item is selected, it will open it for close look")
        }
        
        Button(action: handleEdit) {
            Label("Edit", systemImage: "pencil")
        }.disabled(!inspectEnabled)
            .accessibilityLabel("Edit Selected")
            .accessibilityHint("If only one item is selected, it will open it for editing")
        
        Button(action: handleDelete) {
            Label("Delete", systemImage: "trash")
                .foregroundStyle(.red)
        }.foregroundStyle(.red)
            .accessibilityLabel("Delete Selected")
            .accessibilityHint("Deletes the currently selected data")
    }
}

