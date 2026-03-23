# Deleting Elements

An overview on how to use the deleting system

## Overview

Users need to be able to delete information from the stores. This is very common, so there are tools to help with such actions. These series of tools allow for managing deleting state, signaling on the UI, and obtaining user confirmation. 

This article will overview the basic components, and how the deleting process works.

### General Process

Deleting happens in a series of steps.

1. User selects at least one item, usually provided through a ``LiveSelectionContextProtocol`` conforming type.
2. User either uses a keyboard shortcut (currently not provided), right-clicks and presses "Delete" (using ``SelectionContextMenu``), or uses ``ElementDeleteButton``. 
3. The bound ``DeletingManifest`` will be activated, where its ``DeletingManifest/action`` will be set to the currently selected values.
4. If the UI has ``SwiftUICore/View/withElementDeleting(manifest:post:)`` attached, a confirmation dialog will ask the user if they want to delete.
5. If they choose to delete the data, the modifier will remove it from the store. 
6. If they choose to not delete the data, the ``DeletingManifest`` will be inactive.

Clearly, this subsystem uses several different types. These will be outlined here:

### Helping Types

- ``DeletingManifest``: The main UI state store. It will "activate" when its ``DeletingManifest/action`` is non-`nil`. This signals that the user would like to delete the provided values.
- ``SwiftUICore/View/withElementDeleting(manifest:post:)`` view modifier: A modifier that will:
    - Activate when the deleting manifest activates, asking the user if they truly want to delete data,
    - Handle the deleting by removing it from the view context, and
    - Reseting the ``DeletingManifest`` if the user cancels, or after the deleting completes.
- ``ElementDeleteButton``: A toolbar button that displays as a red trashcan. When selected, it will activate the ``DeletingManifest``.
- ``DeletingActionConfirm``: An encapsulated view to display the "Delete" and "Cancel" buttons of the deleting confirmation. If you are not using ``SwiftUICore/View/withElementDeleting(manifest:post:)``, this will help simplify your workflow.

To help with UI messages, ``DeletingManifest`` is almost always used with ``SelectionWarningManifest``. If the manifest could not activate due to no data being selected, it will put its error there. Therefore, if you use ``DeletingManifest``, it is a good idea to also provide a ``WarningManifest``. 

### Example

```swift
struct ViewWithDeleting<T> : View where T: NSManagedObject {
    @QuerySelection<T> var query;

    @State var delete: DeletingManifest<T> = .init();
    @State var warning: SelectionWarningManifest = .init();

    var body: some View {
        Table(context: query) {
            Text("Name", value: \.name)
            Text("Enum Value", value: \.enumValue)
        }.withWarning(warning)
            .withElementDeleting(manifest: delete) {
                print("Some data was deleted!");
            }
    }
}

```
