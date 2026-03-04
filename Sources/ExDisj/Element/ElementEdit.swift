//
//  ElementEdit.swift
//  Edmund
//
//  Created by Hollan Sellars on 6/21/25.
//

import SwiftUI
import CoreData
import os

/// A high level abstraction over element edting. If `T` is an ``EditableElement``, then it will load the editing view, and handle the layout/closing/saving actions for the process.
@available(macOS 14, iOS 17, *)
public struct ElementEditor<M, T> : View where M: EditableElementManifest, T: TypeTitled & EditableElement, M.Target == T {
    /// Constructs the view using the specified data.
    /// - Parameters:
    ///     - manifest: The ``EditableElementManifest`` manifest used to source information.
    ///     - title: The title of the editor from a ``TypeTitleStrings`` value.
    ///     - postAction: An optional action to run after successfuly saving the data.
    public init(manifest: M, title: KeyPath<TypeTitleStrings, LocalizedStringKey>, postAction: (() -> Void)? = nil) {
        self.manifest = manifest;
        self.postAction = postAction
        self.title = title;
        
    }
    
    private let title: KeyPath<TypeTitleStrings, LocalizedStringKey>;
    private let postAction: (() -> Void)?;
    @State private var manifest: M;
    @Bindable private var otherError: InternalWarningManifest = .init();
    @Bindable private var validationError: WarningManifest<ValidationFailure> = .init()
    
    @Environment(\.managedObjectContext) private var cx;
    @Environment(\.dismiss) private var dismiss;
    
    /// Cancels out the editing.
    private func cancel() {
        manifest.reset();
        dismiss();
    }
    /// Applies the data to the specified data.
    private func apply() -> Bool {
        guard manifest.hasChanges else {
            return true;
        }
        
        do {
            try manifest.save()
            return true;
        }
        catch let e as ValidationFailure {
            self.validationError.warning = e;
            return false;
        }
        catch {
            self.otherError.warning = .init();
            return false;
        }
    }
    /// Run when the `Save` button is pressed. This will validate & apply the data (if it is valid).
    private func submit() {
        if apply() {
            if let post = postAction {
                post()
            }
            
            dismiss();
        }
    }
    
    public var body: some View {
        VStack {
            TypeTitleVisualizer<T>(self.title)
            
            Divider()
            
            self.manifest.target.makeEditView()
            
            Spacer()
            
            HStack{
                Spacer()
                
                Button("Cancel", action: cancel)
                    .buttonStyle(.bordered)
                
                Button("Ok", action: submit)
                    .buttonStyle(.borderedProminent)
            }
        }.padding()
            .withWarning(validationError)
            .withWarning(otherError)
    }
}
@available(macOS 14, iOS 17, *)
extension ElementEditor where M == ElementAddManifest<T> {
    /// Constructs the editor in adding mode.
    /// - Parameters:
    ///     - using: The container to source information from.
    ///     - filling: A routine that sets up default values for `T`.
    ///     - postAction: An optional action to run after successfuly saving the data.
    public init(using: NSPersistentContainer, filling: @MainActor (T) -> Void, postAction: (() -> Void)? = nil ) {
        self.init(
            manifest: .init(using: using, filling: filling),
            title: \.add,
            postAction: postAction
        )
    }
    /// Constructs the editor in adding mode.
    /// - Parameters:
    ///     - addManifest: The ``ElementAddManifest`` to source information from.
    ///     - postAction: An optional action to run after successfuly saving the data.
    public init(addManifest: ElementAddManifest<T>, postAction: (() -> Void)? = nil) {
        self.init(
            manifest: addManifest,
            title: \.add,
            postAction: postAction
        )
    }
}
@available(macOS 14, iOS 17, *)
extension ElementEditor where M == ElementEditManifest<T> {
    /// Constructs the editor in edit mode.
    /// - Parameters:
    ///     - using: The container to source information from.
    ///     - from: The value to edit.
    ///     - postAction: An optional action to run after successfuly saving the data.
    public init(using: NSPersistentContainer, from: T, postAction: (() -> Void)? = nil) {
        self.init(
            manifest: .init(using: using, from: from),
            title: \.edit,
            postAction: postAction
        )
    }
    /// Constructs the editor in edit mode.
    /// - Parameters:
    ///     - editManifest: The ``ElementEditManifest`` to source information from.
    ///     - postAction: An optional action to run after successfuly saving the data.
    public init(editManifest: ElementEditManifest<T>, postAction: (() -> Void)? = nil) {
        self.init(
            manifest: editManifest,
            title: \.edit,
            postAction: postAction
        )
    }
}
