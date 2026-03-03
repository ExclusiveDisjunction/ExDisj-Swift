//
//  Delete.swift
//  Edmund
//
//  Created by Hollan Sellars on 4/22/25.
//

import SwiftUI
import CoreData
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
    
    public func delete<W>(_ context: W, warning: SelectionWarningManifest) where T: Identifiable, W: SelectionContextProtocol, W.Element == T {
        let selection = context.selectedItems;
        guard !selection.isEmpty else {
            warning.warning = .noneSelected;
            return
        }
        
        self.action = selection
    }
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
    
    public var body: some View {
        if let deleting = deleting.action {
            Button("Delete") {
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

@available(macOS 14, iOS 17, *)
public struct DeleteConfirmModifier<T> : ViewModifier where T: Identifiable & NSManagedObject {
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

extension View {
    @available(macOS 14, iOS 17, *)
    public func withElementDeleting<T>(manifest: DeletingManifest<T>, post: (() -> Void)? = nil) -> some View
    where T: Identifiable & NSManagedObject {
        self.modifier(DeleteConfirmModifier<T>(manifest: manifest, post: post))
    }
}
