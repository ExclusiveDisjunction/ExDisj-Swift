# ``HelpKit/HelpEngine``

## Overview

The help engine is the core of the help system. It is the background manager of the help directory, and loads the requested resources for you. It manages a cache, which will keep the commonly accessed pages loaded for quick access. The ``HelpEngine`` is bound to the view environment by default. However, the developer must initialize the engine by calling ``walkDirectory(locator:)`` or ``walkDirectory(baseURL:)``. See <doc:Using-the-Help-System> for more information.

The engine is designed to work without using `Observable` or `ObservableObject` classes, so it can be used on any device that this library supports. 
 
## Topics

### Management

- ``init(_:)``
- ``reset()``
- ``walkDirectory(locator:)``
- ``walkDirectory(baseURL:)``

### Fetching Topics

- ``getTopic(id:)``
- ``getTopic(id:deposit:)``

### Fetching Topic Groups

- ``getGroup(id:)``
- ``getGroup(id:deposit:)``
- ``getTree()``
- ``getTree(deposit:)``
