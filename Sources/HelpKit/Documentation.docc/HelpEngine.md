# ``HelpKit/HelpEngine``

## Overview

The HelpEngine is a centralized resource that performs the heavy lifiting of the library. It keeps an internal list of resources, with their resolved URLs. As users request topics or groups, it will load them, and keep them in a cache. As the cache fills up, it will remove the least recently used item. 

The HelpEngine can be accessed from the UI using the `EnvironmentValue`, ``SwiftUICore/EnvironmentValues/helpEngine``. By default, this is an empty, un-walked engine, that cannot fetch any topics. The developer is tasked to load the engine, walk it, and provide this walked engine to the UI. 

## Topics

### Creating and Walking

- ``HelpEngine/init(_:)``
- ``HelpEngine/walkDirectory(baseURL:fileManager:)``
- ``HelpEngine/walkDirectory(fileManager:bundle:rootDirName:)``
- ``HelpEngine/walkDirectory(fileManager:locateUsing:)``
- ``HelpEngine/reset()``

### Fetching Resources

- ``getTopic(id:)``
- ``getTopic(id:deposit:)``
- ``getGroup(id:)``
- ``getGroup(id:deposit:)``
- ``getTree()``
- ``getTree(deposit:)``
