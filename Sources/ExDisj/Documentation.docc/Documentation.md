# ``ExDisj``

Collection of swift related resources for building apps.

## Overview

ExDisj is a package built upon SwiftUI. It has common elements for representing, modifying, visualizing, and managing data. This framework is designed to be very flexible and dynamic, so it can be used in many different contexts. Additionally, this library is built upon the Core Data libraries.

## Topics

### Elements

- <doc:Using-Elements>
- ``ElementBase``
- ``NamedElement``
- ``DefaultableElement``
- ``IsolatedDefaultableElement``
- ``EditableElement``
- ``InspectableElement``
- ``NamedVisualizer``
- ``ElementPicker``

### Data Selection

- <doc:Using-Selection>
- ``SelectionContextProtocol``
- ``LiveSelectionContextProtocol``
- ``SelectionContext``
- ``FrozenSelectionContext``
- ``QuerySelection``
- ``FilterableQuerySelection``
- ``SourcedSelection``
- ``SwiftUI/List/init(context:rowContent:)``
- ``SwiftUI/Table/init(context:columns:)``
- ``SwiftUI/Table/init(context:sortOrder:columns:)``

### Inspection, Adding, and Editing Elements

- <doc:Managing-Elements>
- ``InspectionState``
- ``InspectionManifest``

- ``EditableElementManifest``
- ``ElementAddManifest``
- ``ElementEditManifest``
- ``ElementSelectionMode``

- ``ElementEditButton``
- ``ElementInspectButton``
- ``ElementAddButton``

- ``ElementInspector``
- ``ElementEditor``
- ``ElementIE``

- ``SwiftUICore/View/withElementInspector(manifest:)``
- ``SwiftUICore/View/withElementEditor(manifest:using:filling:post:)``
- ``SwiftUICore/View/withElementIE(manifest:using:filling:post:)``

- ``SelectionContextMenu``
- ``SingularContextMenu``

### Deleting

- <doc:Deleting-Elements>
- ``DeletingManifest``
- ``ElementDeleteButton``
- ``DeletingActionConfirm``
- ``SwiftUICore/View/withElementDeleting(manifest:post:)``

### Warnings

- <doc:Using-Warnings>
- ``WarningBasis``
- ``WarningManifest``
- ``SwiftUICore/View/withWarning(_:)``
- ``StringWarning``
- ``StringWarningManifest``
- ``SelectionWarningKind``
- ``SelectionWarningManifest``
- ``InternalErrorWarning``
- ``InternalWarningManifest``
- ``ValidationFailureReason``
- ``ValidationFailure``
- ``ValidationFailureBuilder``
- ``ValidationWarningManifest``

### Help System

- <doc:Using-the-Help-System>
- ``HelpEngine``
- ``HelpResourcesLocator``
- ``DefaultHelpResourcesLocator``
- ``SwiftUICore/EnvironmentValues/helpEngine``

- ``HelpResourceID``
- ``HelpResource``
- ``HelpResourcePlaceholder``
- ``HelpTopic``
- ``HelpGroup``
- ``UnloadedHelpResource``
- ``LoadedHelpTopic``
- ``LoadedHelpGroup``
- ``LoadedHelpResource``

- ``ResourceLoadState``
- ``TopicLoadState``
- ``TopicFetchError``
- ``GroupLoadState``
- ``GroupFetchError``

- ``HelpResourcePresenter``
- ``HelpPresenterContentProtocol``
- ``TopicPresenter``
- ``TopicGroupPresenter``
- ``HelpTreePresenter``

- ``HelpButtonBase``
- ``HelpToolbarButton``
- ``TopicButton``
- ``TopicButtonStyle``
- ``TopicGroupButton``
- ``TopicToolbarButton``
- ``TopicGroupToolbarButton``


### Time 

- ``Foundation/Date/fromParts(_:_:_:)``
- ``TimePeriods``
- ``MonthlyTimePeriods``
- ``MonthYear``
- ``TimePeriodWalker``

### Miscellaneous Tools

- ``TypeTitleStrings``
- ``TypeTitled``
- ``TypeTitleVisualizer``
- ``Displayable``
- ``DisplayableVisualizer``
- ``SwiftUI/TableColumn/init(_:value:)``
- ``EnumPicker``
- ``NullableValue``
- ``LimitedQueue``
- ``LimitedQueueIterator``
- ``SheetBody``
- ``OkButton``
- ``FilterSubsection``
