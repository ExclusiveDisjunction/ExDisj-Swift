//
//  ElementIE.swift
//  Edmund
//
//  Created by Hollan Sellars on 4/21/25.
//

import SwiftUI;
import CoreData
import os

/// A high level view that allows for switching between editing and inspecting an element.
///
/// Internally, this view uses the warning manifests, so it cannot be used before macOS 14 or iOS 17.
@available(macOS 14, iOS 17, *)
public struct ElementIE<T> : View where T: InspectableElement & EditableElement & NSManagedObject & TypeTitled {
    
    /// Constructs the view in add mode, using a function to create a default value.
    ///  - Parameters:
    ///     - addingTo: The `NSPersistentContainer` to add to.
    ///     - filling: A closure that creates a default value of `T`, after creation.
    ///     - postAction: An optional closure to run after a successful save/dismissal is completed.
    ///
    /// Unlike ``ElementAddManifest``, this does not allow for a throwing `filling` function. If you must have a throwing function, create the manifest on your own, and use ``init(adding:postAction:)``.
    ///
    /// By default, this locks the user from switching mode to inspection.
    public init(
        addingTo: DataStack,
        filling: @MainActor (T) -> Void,
        postAction: (() -> Void)? = nil
    ) {
        self.state = ElementSelectionMode.newAdd(using: addingTo, filling: filling)
        self.canChangeState = false;
        self.postAction = postAction;
        self.source = addingTo;
    }
    /// Constructs the view in add mode, using a pre-created manifest.
    /// - Parameters:
    ///     - adding: The pre-created manifest to source information from.
    ///     - postAction: An optional closure to run after a successful save/dismissal is completed.
    ///
    ///  By default, this locks the user from switching mode to inspection.
    ///  - Note: The view will be bound to the same `NSPersistentContainer` that the manifest was created with.
    public init(
        adding: ElementAddManifest<T>,
        postAction: (() -> Void)? = nil
    ) {
        self.state = .add(adding)
        self.canChangeState = false;
        self.postAction = postAction;
        self.source = adding.container;
    }
    /// Constructs the view in edit mode, creating the manifest internally.
    /// - Parameters:
    ///     - editingFrom: The `NSPersistentContainer` to edit from.
    ///     - editing: The target data to edit.
    ///     - postAction: An optional closure to run after a successful save/dismissal is completed.
    ///
    /// Unlike ``ElementEditManifest``, this view cannot be constructed from a direct `NSManagedObjectID` (as the types might mismatch). If you must construct from a `NSManagedObjectID`, use ``init(edit:postAction:)``
    ///
    /// - Warning: If the target data did not come from the passed container,  the view may do undefined behaviors and/or crashes.
    public init(
        editingFrom: DataStack,
        editing: T,
        postAction: (() -> Void)? = nil
    ) {
        self.state = ElementSelectionMode.newEdit(using: editingFrom, from: editing)
        self.canChangeState = true;
        self.postAction = postAction;
        self.source = editingFrom;
    }
    /// Construct the view in edit mode, using a pre-created manifest.
    /// - Parameters:
    ///     - edit: The pre-created manifest to source information from.
    ///     - postAction: An optional closure to run after a successful save/dismissal is completed.
    ///
    ///  - Note: The view will be bound to the same `NSPersistentContainer` that the manifest was created with.
    public init(
        edit: ElementEditManifest<T>,
        postAction: (() -> Void)? = nil
    ) {
        self.state = .edit(edit)
        self.canChangeState = true;
        self.postAction = postAction;
        self.source = edit.container;
    }
    /// Constructs the view in inspect mode from pre-sourced information.
    /// - Parameters:
    ///     - viewingFrom: The `NSPersistentContainer` the information is sourced from.
    ///     - viewing: The information to inspect.
    ///     - postAction: An optional closure to run after a successful save/dismissal is completed.
    ///
    /// - Note: The `viewingFrom` container is used only if the user switches to edit mode.
    /// - Warning: If the target data did not come from the passed container,  the view may do undefined behaviors and/or crashes.
    public init(
        viewingFrom: DataStack,
        viewing: T,
        postAction: (() -> Void)? = nil
    ) {
        self.state = .inspect(viewing)
        self.canChangeState = true;
        self.postAction = postAction;
        self.source = viewingFrom;
    }
    
    @State private var state: ElementSelectionMode<T>;
    @State private var warningConfirm: Bool = false;
    
    @Environment(\.dismiss) private var dismiss;
    
    private var otherErrors: InternalWarningManifest = .init();
    private var validationError: ValidationWarningManifest = .init();
    
    private let canChangeState: Bool;
    private let postAction: (() -> Void)?;
    private let source: DataStack;
    
    /// Determining  if the editor is in edit mode (adding or editing)
    private var isEdit: Bool {
        switch self.state {
            case .add(_): true
            case .edit(_): true
            case .inspect(_): false
        }
    }
    private var modeKey: KeyPath<TypeTitleStrings, LocalizedStringKey> {
        switch self.state {
            case .add(_): \.add
            case .edit(_): \.edit
            case .inspect(_): \.inspect
        }
    }
    private var target: (T, Bool) { // (Target, IsEdit)
        switch self.state {
            case .add(let m): (m.target, true)
            case .edit(let m): (m.target, true)
            case .inspect(let t): (t, false)
        }
    }
    
    @discardableResult
    private func submit(dismissOnCompletion: Bool = true) -> Bool {
        do {
            switch self.state {
                case .add(let v): try v.save()
                case .edit(let v): try v.save()
                default: ()
            }
            
            if dismissOnCompletion {
                dismiss();
            }
            if let post = postAction {
                post()
            }
            
            return true;
        }
        catch let e as ValidationFailure {
            self.validationError.warning = e;
        }
        catch {
            self.otherErrors.warning = .init();
        }
        
        return false;
    }
    private func cancel() {
        switch self.state {
            case .add(let v): v.reset()
            case .edit(let v): v.reset()
            case .inspect(_): ()
        }
        
        dismiss();
    }
    private func switchMode() {
        guard self.canChangeState else {
            self.otherErrors.warning = .init();
            return;
        }
        
        switch self.state {
            case .edit(let m):
                guard m.hasChanges else {
                    break;
                }
                
                warningConfirm = true;
                return;
            case .add(let m):
                guard m.hasChanges else {
                    break;
                }
                
                warningConfirm = true;
                return;
            default: ()
        }
        
        self.completeTransition();
    }
    private func completeTransition() {
        let newState: ElementSelectionMode<T> = switch self.state {
            case .edit(let e): .inspect(e.target)
            case .add(let e): .inspect(e.target)
            case .inspect(let e): .edit(.init(using: self.source, from: e))
        }
        
        self.state = newState;
    }
    
    @ViewBuilder
    private var confirm: some View {
        Button("Save") {
            warningConfirm = false
            
            guard self.submit(dismissOnCompletion: false) else {
                return;
            }
           
            self.completeTransition();
        }
        
        Button("Revert Changes") {
            switch self.state {
                case .add(let m): m.reset()
                case .edit(let m): m.reset()
                default: ()
            }
            
            warningConfirm = false
            self.completeTransition()
        }
        
        Button("Cancel", role: .cancel) {
            warningConfirm = false
        }
    }
    
    public var body: some View {
        VStack {
            TypeTitleVisualizer<T>(modeKey)
            
            let (target, isEdit) = self.target;
            
            Button {
                withAnimation {
                    switchMode()
                }
            } label: {
                Image(systemName: isEdit ? "info.circle" : "pencil")
                    .resizable()
            }.buttonStyle(.borderless)
                .scaledToFit()
                .frame(width: 20, height: 20)
                .disabled(!canChangeState) //you cannot change mode if the data is not stored.
                .accessibilityLabel(isEdit ? "Switch to Inspection Mode" : "Switch to Edit Mode")
#if os(iOS)
                .padding(.bottom)
#endif
            
            Divider()
            
            if isEdit {
                target.makeEditView()
            }
            else {
                target.makeInspectView()
            }
            
            Spacer()
            
            HStack{
                Spacer()
                
                if isEdit {
                    Button("Cancel", action: cancel).buttonStyle(.bordered)
                }
                
                Button(isEdit ? "Save" : "Ok") {
                    submit()
                }.buttonStyle(.borderedProminent)
            }
        }.padding()
            .withWarning(otherErrors)
            .withWarning(validationError)
            .confirmationDialog(
                "There are unsaved changes, do you wish to continue?",
                isPresented: $warningConfirm,
                titleVisibility: .visible
            ) {
                confirm
            }
    }
}
