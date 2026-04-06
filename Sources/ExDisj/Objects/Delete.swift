//
//  Delete.swift
//  Edmund
//
//  Created by Hollan Sellars on 4/22/25.
//

import SwiftUI
import CoreData
import SwiftData
import os

/// An observable class that provides deleting confrimation dialog abstraction. It includes a member, `isDeleting`, which can be bound. This value will become `true` when the internal list is not `nil` and not empty.
@available(macOS 14, iOS 17, *)
@Observable
public class DeletingManifest<T> where T: Identifiable {
    public init() { }
    
    /// The objects to delete.
    public final var action: [T]?;
    /// A bindable value that returns true when the `action` is not `nil` and the list is not empty.
    public final var isDeleting: Bool {
        get {
            guard let action = action else { return false }
            
            return !action.isEmpty
        }
        set {
            if self.isDeleting == newValue {
                return
            }
            else {
                if newValue {
                    action = []
                }
                else {
                    action = nil
                }
            }
        }
    }
    
    /// Selects the elements out of the `context` and marks them for deletion.
    /// - Parameters:
    ///     - context: The data context to select information from.
    ///     - warning: The warning manifest to indicate user error.
    public func delete<W>(_ context: W, warning: SelectionWarningManifest) where T: Identifiable, W: SelectionContextProtocol, W.Element == T {
        let selection = context.selectedItems;
        guard !selection.isEmpty else {
            warning.warning = .noneSelected;
            return
        }
        
        self.action = selection
    }
    /// Selects the element out of `from` matching the provided `id`, and marks that object for deletion.
    /// - Parameters:
    ///     - from: The list to source information out of
    ///     - id: The ID of the element to remove
    ///     - warning: The warning manifest to indicate user error.
    public func delete<C>(from: C, id: T.ID, warning: SelectionWarningManifest) where T: Identifiable, C: Collection, C.Element == T {
        guard let target = from.first(where: { $0.id == id }) else {
            warning.warning = .noneSelected;
            return;
        }
        
        self.action = [target];
    }
}

/// An abstraction to show in the `.confirmationDialog` of a view. This will handle the deleting of the data inside of a `DeletingManifest<T>`.
@available(macOS 14, iOS 17, *)
public struct DeletingActionConfirm<T>: View where T: NSManagedObject & Identifiable {
    /// The data that can be deleted.
    private var deleting: DeletingManifest<T>;
    /// Runs after the deleting occurs.
    private let postAction: (() -> Void)?;
    
    /// Constructs the view around the specified data
    /// - Parameters:
    ///     - deleting: The `DeletingManifest<T>` source of truth..
    ///     - post: An action to run after the removal occurs. If the user cancels, this will not be run.
    public init(_ deleting: DeletingManifest<T>, post: (() -> Void)? = nil) {
        self.deleting = deleting
        self.postAction = post
    }
    
    @Environment(\.managedObjectContext) private var objectContext;
    @Environment(\.dismiss) private var dismiss;
    
    private func performDelete(_ deleting: [T]) {
        for data in deleting {
            objectContext.delete(data);
        }
        
        do {
            try objectContext.save();
        }
        catch {
            dismiss();
            
            return;
        }
        
        self.deleting.isDeleting  = false
        if let post = postAction {
            post()
        }
    }
    
    public var body: some View {
        if let deleting = deleting.action {
            Button("Delete") {
                performDelete(deleting)
            }
        }
        
        Button("Cancel", role: .cancel) {
            deleting.isDeleting = false
        }
    }
}

public struct SwiftDataDeletingActionConfirm<T>: View where T: PersistentModel & Identifiable {
    /// The data that can be deleted.
    private var deleting: DeletingManifest<T>;
    /// Runs after the deleting occurs.
    private let postAction: (() -> Void)?;
    
    /// Constructs the view around the specified data
    /// - Parameters:
    ///     - deleting: The `DeletingManifest<T>` source of truth..
    ///     - post: An action to run after the removal occurs. If the user cancels, this will not be run.
    public init(_ deleting: DeletingManifest<T>, post: (() -> Void)? = nil) {
        self.deleting = deleting
        self.postAction = post
    }
    
    @Environment(\.modelContext) private var modelContext;
    @Environment(\.dismiss) private var dismiss;
    
    private func performDelete(_ deleting: [T]) {
        for data in deleting {
            modelContext.delete(data);
        }
        
        do {
            try modelContext.save();
        }
        catch {
            dismiss();
            
            return;
        }
        
        self.deleting.isDeleting  = false
        if let post = postAction {
            post()
        }
    }
    
    public var body: some View {
        if let deleting = deleting.action {
            Button("Delete") {
                performDelete(deleting)
            }
        }
        
        Button("Cancel", role: .cancel) {
            deleting.isDeleting = false
        }
    }
}

/// A toolbar button that can be used to signal the deleting of objects over a `DeletingManifest<T>` and `WarningManifest`.
@available(macOS 14, iOS 17, *)
public struct ElementDeleteButton<W> : CustomizableToolbarContent where W: SelectionContextProtocol {
    /// Constructs the toolbar with the needed abstraction information.
    /// - Parameters:
    ///     - context: The selection and data to delete from.
    ///     - delete: The `DeletingManifest<T>` used to signal the intent to remove elements.
    ///     - warning: The warning manifest used to signal user mistakes.
    ///     - placement: A customization of where the delete button should go.
    public init(context: W, delete: DeletingManifest<W.Element>, warning: SelectionWarningManifest, placement: ToolbarItemPlacement = .automatic) {
        self.context = context
        self.delete = delete
        self.warning = warning
        self.placement = placement
    }
    
    private let context: W;
    private let delete: DeletingManifest<W.Element>;
    private let warning: SelectionWarningManifest;
    private let placement: ToolbarItemPlacement;
    
    @ToolbarContentBuilder
    public var body: some CustomizableToolbarContent {
        ToolbarItem(id: "elementDelete", placement: placement) {
            Button {
                delete.delete(context, warning: warning)
            } label: {
                Label("Delete", systemImage: "trash").foregroundStyle(.red)
            }
        }
    }
}

/// A modifier that attaches a deleting confirm dialog.
@available(macOS 14, iOS 17, *)
fileprivate struct DeleteConfirmModifier<T> : ViewModifier where T: Identifiable & NSManagedObject {
    /// Constructs the modifier from a manifest and a post action.
    /// - Parameters:
    ///     - manifest: The ``DeletingManifest`` to source information from.
    ///     - post: An action to take after deleting the object(s).
    public init(manifest: DeletingManifest<T>, post: (() -> Void)? = nil) {
        self.manifest = manifest;
        self.post = post;
    }
    
    @Bindable private var manifest: DeletingManifest<T>;
    private let post: (() -> Void)?;
    
    public func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Are you sure you want to delete these items?",
                isPresented: $manifest.isDeleting,
                titleVisibility: .visible
            ) {
                DeletingActionConfirm(manifest, post: post)
            }
    }
}

fileprivate struct SwiftDataDeleteConfirmModifier<T> : ViewModifier where T: Identifiable & PersistentModel {
    /// Constructs the modifier from a manifest and a post action.
    /// - Parameters:
    ///     - manifest: The ``DeletingManifest`` to source information from.
    ///     - post: An action to take after deleting the object(s).
    public init(manifest: DeletingManifest<T>, post: (() -> Void)? = nil) {
        self.manifest = manifest;
        self.post = post;
    }
    
    @Bindable private var manifest: DeletingManifest<T>;
    private let post: (() -> Void)?;
    
    public func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Are you sure you want to delete these items?",
                isPresented: $manifest.isDeleting,
                titleVisibility: .visible
            ) {
                SwiftDataDeletingActionConfirm(manifest, post: post)
            }
    }
}

extension View {
    /// Attaches a deleting confirm dialog that activates whenever the ``DeletingManifest`` becomes active.
    /// This overload is for core data types.
    ///
    /// - Note: If any element is unique, the unique engine will not be notified of the removal, except for automatic tracking (See ``UniqueEngine``).
    /// - Parameters:
    ///     - manifest: The ``DeletingManifest`` to source information from.
    ///     - post: An action to take after deleting the object(s).
    @available(macOS 14, iOS 17, *)
    public func withElementDeleting<T>(manifest: DeletingManifest<T>, post: (() -> Void)? = nil) -> some View
    where T: Identifiable & NSManagedObject {
        self.modifier(DeleteConfirmModifier<T>(manifest: manifest, post: post))
    }
    
    /// Attaches a deleting confirm dialog that activates whenever the ``DeletingManifest`` becomes active.
    /// This overload is for swift data types.
    ///
    /// - Note: If any element is unique, the unique engine will not be notified of the removal, except for automatic tracking (See ``UniqueEngine``).
    /// - Parameters:
    ///     - manifest: The ``DeletingManifest`` to source information from.
    ///     - post: An action to take after deleting the object(s).
    public func withElementDeleting<T>(manifest: DeletingManifest<T>, post: (() -> Void)? = nil) -> some View
    where T: Identifiable & PersistentModel {
        self.modifier(SwiftDataDeleteConfirmModifier<T>(manifest: manifest, post: post))
    }
}
