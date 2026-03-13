//
//  Inspect.swift
//  Edmund
//
//  Created by Hollan Sellars on 4/22/25.
//

import SwiftUI
import CoreData

/// A combination signals used to indicate what you want to do with a specific data element.
public enum InspectionState<T> : Identifiable where T: Identifiable {
    /// Signals the data should be edited
    case edit(T)
    /// Signals the data should be viewed/inspected
    case inspect(T)
    /// Singlas the data is being added. This is essentially `Self.edit`, but gives extra context.
    case add
    
    public enum ID : Hashable {
        case add
        case object(T.ID)
    }
    
    public var id: ID {
        switch self {
            case .edit(let v): .object(v.id)
            case .inspect(let v): .object(v.id)
            case .add: .add
        }
    }
    
    /// The icon used for the specific mode. Note that `Self.add` should not be used in this context.
    public var icon: String {
        switch self {
            case .edit: "pencil"
            case .inspect: "info.circle"
            case .add: "exclimationmark"
        }
    }
}

/// A wrapper that allows for streamlined signaling of inspection/editing/adding for a data type.
@available(macOS 14, iOS 17, *)
@Observable
public class InspectionManifest<T> where T: Identifiable {
    public init() {
        mode = nil;
    }
    
    /// The current mode being taken by the manifest.
    public var mode: InspectionState<T>?;
    
    
    /// Determines if the manifest is in edit, add, or inspect mode.
    public var isActive: Bool {
        self.mode != nil
    }
    
    /// Opens the selected element, if exactly one element is selected.
    /// - Parameters:
    ///     - selection: The selection context to source from.
    ///     - editing: Indicates to the manifest if the selected value is to be edited or inspected.
    ///     - warning: A warning manifest to indicate issues with selection quantity.
    public func open<W>(selection: W, editing: Bool, warning: SelectionWarningManifest) where W: SelectionContextProtocol, W.Element == T {
        let objects = selection.selectedItems
        
        guard !objects.isEmpty else { warning.warning = .noneSelected; return }
        guard objects.count == 1 else { warning.warning = .tooMany; return }
        guard let target = objects.first else { warning.warning = .noneSelected; return }
        
        self.open(value: target, editing: editing)
    }
    /// Opens the selected element for inspection or editing.
    /// - Parameters:
    ///     - value: The object to edit or inspect.
    ///     - editing: Indicates to the manifest if the `value` is to be edited or inspected.
    public func open(value: T, editing: Bool) {
        self.mode = editing ? .edit(value) : .inspect(value);
    }
    /// Instructs the manifest to go into add mode.
    public func openAdding() {
        self.mode = .add;
    }
}

/// A general toolbar item for inspecting or editing elements.
@available(macOS 14, iOS 17, *)
fileprivate struct InspectionManifestToolbarButton<W> : CustomizableToolbarContent where W: SelectionContextProtocol {
    public init(
        context: W,
        inspect: InspectionManifest<W.Element>,
        warning: SelectionWarningManifest,
        isEdit: Bool,
        placement: ToolbarItemPlacement
    ) {
        self.context = context;
        self.inspect = inspect;
        self.warning = warning;
        self.placement = placement
        self.isEdit = isEdit
    }
    
    private let context: W;
    private let inspect: InspectionManifest<W.Element>;
    private let warning: SelectionWarningManifest;
    private let isEdit: Bool;
    private let placement: ToolbarItemPlacement;
    
    @ToolbarContentBuilder
    var body: some CustomizableToolbarContent {
        ToolbarItem(id: isEdit ? "inspectionEdit" : "inspectionInspect", placement: placement) {
            Button {
                inspect.open(selection: context, editing: isEdit, warning: warning)
            } label: {
                Label(isEdit ? "Edit" : "Inspect", systemImage: isEdit ? "pencil" : "info.circle")
            }
        }
    }
}

/// A toolbar button used to signal the inspection of elements from the main data source.
@available(macOS 14, iOS 17, *)
public struct ElementInspectButton<W> : CustomizableToolbarContent where W: SelectionContextProtocol {
    public init(
        context: W,
        inspect: InspectionManifest<W.Element>,
        warning: SelectionWarningManifest,
        placement: ToolbarItemPlacement = .automatic
    ) {
        self.context = context;
        self.inspect = inspect;
        self.warning = warning;
        self.placement = placement
    }
    
    private let context: W;
    private let inspect: InspectionManifest<W.Element>;
    private let warning: SelectionWarningManifest;
    private let placement: ToolbarItemPlacement;
    
    @ToolbarContentBuilder
    public var body: some CustomizableToolbarContent {
        InspectionManifestToolbarButton(context: context, inspect: inspect, warning: warning, isEdit: false, placement: placement)
    }
}

/// A toolbar button used to signal the editing of elements from the main data source.
@available(macOS 14, iOS 17, *)
public struct ElementEditButton<W> : CustomizableToolbarContent where W: SelectionContextProtocol {
    public init(
        context: W,
        inspect: InspectionManifest<W.Element>,
        warning: SelectionWarningManifest,
        placement: ToolbarItemPlacement = .automatic
    ) {
        self.context = context;
        self.inspect = inspect;
        self.warning = warning;
        self.placement = placement
    }
    
    private let context: W;
    private let inspect: InspectionManifest<W.Element>;
    private let warning: SelectionWarningManifest;
    private let placement: ToolbarItemPlacement;
    
    @ToolbarContentBuilder
    public var body: some CustomizableToolbarContent {
        InspectionManifestToolbarButton(context: context, inspect: inspect, warning: warning, isEdit: true, placement: placement)
    }
}

/// A toolbar button used to signal the adding of new elements to the main data source.
@available(macOS 14, iOS 17, *)
public struct ElementAddButton<T> : CustomizableToolbarContent where T: Identifiable {
    public init(inspect: InspectionManifest<T>, placement: ToolbarItemPlacement = .automatic) {
        self.inspect = inspect;
        self.placement = placement;
    }
    
    private let inspect: InspectionManifest<T>;
    private let placement: ToolbarItemPlacement;
    
    @ToolbarContentBuilder
    public var body: some CustomizableToolbarContent {
        ToolbarItem(id: "inspectionAdd", placement: placement) {
            Button {
                inspect.openAdding()
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
    }
}

/// A view modifier that attaches an ``ElementInspector`` that activates when the ``InspectionManifest`` goes into inspection mode.
/// - Warning: Do not use this modifier with ``WithEditorModifier`` or ``WithInspectorEditorModifier``, as they are not compatible.
@available(macOS 14, iOS 17, *)
fileprivate struct WithInspectorModifier<T> : ViewModifier where T: Identifiable & NSManagedObject & InspectableElement & TypeTitled {
    public init(manifest: InspectionManifest<T>) {
        self.manifest = manifest
    }
    
    @Bindable private var manifest: InspectionManifest<T>;
    
    public func body(content: Content) -> some View {
        content
            .sheet(item: $manifest.mode) { mode in
                switch mode {
                    case .inspect(let target): ElementInspector(data: target)
                    default:
                        VStack {
                            Spacer()
                            Text("The target data does not support editing. Please report this issue.")
                            Spacer()
                            
                            Button("Ok") {
                                manifest.mode = nil;
                            }
                        }
                }
            }
    }
}

/// A view modifier that attaches an ``ElementEditor`` that activates when the ``InspectionManifest`` goes into editing or adding mode.
/// - Warning: Do not use this modifier with ``WithInspectorModifier`` or ``WithInspectorEditorModifier``, as they are not compatible.
@available(macOS 14, iOS 17, *)
fileprivate struct WithEditorModifier<T> : ViewModifier where T: Identifiable & NSManagedObject & EditableElement & TypeTitled {
    public init(manifest: InspectionManifest<T>, using: DataStack, filling: @MainActor @escaping (T) -> Void, post: (() -> Void)? = nil) {
        self.manifest = manifest
        self.using = using
        self.post = post;
        self.filling = filling;
    }
    
    @Bindable private var manifest: InspectionManifest<T>;
    private let using: DataStack;
    private let post: (() -> Void)?;
    private let filling: @MainActor (T) -> Void;
    
    public func body(content: Content) -> some View {
        content
            .sheet(item: $manifest.mode) { mode in
                switch mode {
                    case .add: ElementEditor(using: self.using, filling: filling, postAction: post)
                    case .edit(let target): ElementEditor(using: self.using, from: target, postAction: post)
                    default:
                        VStack {
                            Spacer()
                            Text("The target data does not support inspection. Please report this issue.")
                            Spacer()
                            
                            Button("Ok") {
                                manifest.mode = nil;
                            }
                        }
                }
            }
    }
}

/// A view modifier that attaches an ``ElementIE`` that activates when the ``InspectionManifest`` activates in any mode.
/// - Warning: Do not use this modifier with ``WithEditorModifier`` or ``WithInspectorModifier``, as they are not compatible.
@available(macOS 14, iOS 17, *)
fileprivate struct WithInspectorEditorModifier<T> : ViewModifier where T: Identifiable & NSManagedObject & InspectableElement & EditableElement & TypeTitled {
    public init(manifest: InspectionManifest<T>, using: DataStack, filling: @MainActor @escaping (T) -> Void, post: (() -> Void)? = nil) {
        self.manifest = manifest;
        self.using = using;
        self.filling = filling;
        self.post = post;
    }
    
    @Bindable private var manifest: InspectionManifest<T>;
    private let using: DataStack;
    private let post: (() -> Void)?;
    private let filling: @MainActor (T) -> Void;
    
    public func body(content: Content) -> some View {
        content
            .sheet(item: $manifest.mode) { mode in
                switch mode {
                    case .add: ElementIE(addingTo: using, filling: filling, postAction: post)
                    case .edit(let target): ElementIE(editingFrom: using, editing: target, postAction: post)
                    case .inspect(let target): ElementIE(viewingFrom: using, viewing: target, postAction: post)
                }
            }
    }
}

@available(macOS 14, iOS 17, *)
public extension View {
    /// Attaches a sheet to the view that activates whenever the user marks a specific object for inspection.
    /// - Parameters:
    ///     - manifest: The ``InspectionManifest`` to pull information from.
    ///
    /// - Warning: If using the same ``InspectionManifest``, do not use with ``withElementEditor(manifest:using:filling:post:)`` or ``withElementIE(manifest:using:filling:post:)``, as they are not compatible.
    func withElementInspector<T>(
        manifest: InspectionManifest<T>
    ) -> some View
    where T: InspectableElement & TypeTitled & Identifiable & NSManagedObject {
        self.modifier(WithInspectorModifier(manifest: manifest))
    }
    
    /// Attaches a sheet to the view that activates whenever the user marks a specific object for editing or adding.
    /// - Parameters:
    ///     - manifest: The ``InspectionManifest`` to pull information from.
    ///     - using: The `NSPersistentContainer` to add/edit information to/from. It is undefined behavior if the information being editied comes from a different container.
    ///     - filling: The closure to use for creating default values of `T`, if such an action occurs.
    ///     - post: Any actions to run after a sucessful save.
    ///
    /// - Warning: If using the same ``InspectionManifest``, do not use with ``withElementInspector(manifest:)`` or ``withElementIE(manifest:using:filling:post:)``, as they are not compatible.
    func withElementEditor<T>(
        manifest: InspectionManifest<T>,
        using: DataStack,
        filling: @MainActor @escaping (T) -> Void,
        post: (() -> Void)? = nil
    ) -> some View
    where T: EditableElement & TypeTitled & Identifiable & NSManagedObject {
        self.modifier(WithEditorModifier(manifest: manifest, using: using, filling: filling, post: post))
    }
    
    /// Attaches a sheet to the view that activates whenever the user marks a specific object for inspection, adding, or editing.
    /// - Parameters:
    ///     - manifest: The ``InspectionManifest`` to pull information from.
    ///     - using: The `NSPersistentContainer`  to add/edit information to/from. It is undefined behavior if the information being editied comes from a different container.
    ///     - filling: The closure to use for creating default values of `T`, if such an action occurs.
    ///     - post: Any actions to run after a sucessful save.
    /// - Warning: If using the same ``InspectionManifest``, do not use with ``withElementEditor(manifest:using:filling:post:)`` or ``withElementInspector(manifest:)``, as they are not compatible.
    func withElementIE<T>(
        manifest: InspectionManifest<T>,
        using: DataStack,
        filling: @MainActor @escaping (T) -> Void,
        post: (() -> Void)? = nil
    ) -> some View
    where T: EditableElement & InspectableElement & TypeTitled & Identifiable & NSManagedObject {
        self.modifier(WithInspectorEditorModifier(manifest: manifest, using: using, filling: filling, post: post))
    }
}
