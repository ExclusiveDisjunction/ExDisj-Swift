//
//  ElementEdit.swift
//  Edmund
//
//  Created by Hollan Sellars on 6/21/25.
//

import SwiftUI
import CoreData
import SwiftData
import os

/// A high level abstraction over element edting. If `T` is an ``EditableElement``, then it will load the editing view, and handle the layout/closing/saving actions for the process.
@available(macOS 14, iOS 17, *)
public struct ElementEditor<Manifest, Container> : View
where Manifest: EditableElementManifest,
      Manifest.Target: EditableElement & TypeTitled & AnyObject & Hashable,
      Manifest.Container: ContainerProtocol & EnvAccessibleContainer,
      Manifest.Container == Container
{
    /// Constructs the view using the specified data.
    /// - Parameters:
    ///     - manifest: The ``EditableElementManifest`` manifest used to source information.
    ///     - title: The title of the editor from a ``TypeTitleStrings`` value.
    ///     - postAction: An optional action to run after successfuly saving the data.
    public init(manifest: Manifest, title: KeyPath<TypeTitleStrings, LocalizedStringKey>, postAction: (() -> Void)? = nil) {
        self.manifest = manifest;
        self.postAction = postAction
        self.title = title;
        
    }
    
    private let title: KeyPath<TypeTitleStrings, LocalizedStringKey>;
    private let postAction: (() -> Void)?;
    @State private var manifest: Manifest;
    @State private var otherError: InternalWarningManifest = .init();
    @State private var validationError: WarningManifest<ValidationFailure> = .init()
    
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
            TypeTitleVisualizer<Manifest.Target>(self.title)
            
            Divider()
            
            self.manifest.target.makeEditView()
                .environment(Manifest.Container.contextKeyPath, manifest.context)
            
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
extension ElementEditor {
    /// Constructs the editor in adding mode.
    /// - Parameters:
    ///     - addManifest: The ``ElementAddManifest`` to source information from.
    ///     - postAction: An optional action to run after successfuly saving the data.
    public init<T>(addManifest: ElementAddManifest<T, Container>, postAction: (() -> Void)? = nil)
    where Manifest == ElementAddManifest<T, Container> {
        self.init(
            manifest: addManifest,
            title: \.add,
            postAction: postAction
        )
    }
}
@available(macOS 14, iOS 17, *)
extension ElementEditor {
    /// Constructs the editor in adding mode.
    /// - Parameters:
    ///     - using: The container to source information from.
    ///     - filling: A routine that sets up default values for `T`.
    ///     - postAction: An optional action to run after successfuly saving the data.
    public init<T>(using: NSPersistentContainer, filling: @MainActor (T, NSManagedObjectContext) -> Void, postAction: (() -> Void)? = nil)
    where Manifest == ElementAddManifest<T, NSPersistentContainer>
    {
        self.init(
            addManifest: .init(using: using, filling: filling),
            postAction: postAction
        )
    }
}

@available(macOS 14, iOS 17, *)
extension ElementEditor {
    /// Constructs the editor in adding mode.
    /// - Parameters:
    ///     - using: The container to source information from.
    ///     - filling: A routine that sets up default values for `T`.
    ///     - postAction: An optional action to run after successfuly saving the data.
    public init<T>(using: SwiftDataStack, filling: @MainActor (ModelContext) -> T, postAction: (() -> Void)? = nil )
    where Manifest == ElementAddManifest<T, SwiftDataStack>,
          Container == SwiftDataStack,
          T: PersistentModel
    {
        let newManifest = ElementAddManifest(using: using, filling: filling);
        self.init(
            addManifest: newManifest,
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
    public init(using: DataStack, from: T, postAction: (() -> Void)? = nil) {
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
