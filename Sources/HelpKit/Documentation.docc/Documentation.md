# ``HelpKit``

A series of utilities to display text files, RTF files, and markdown files on the UI, as a series of help articles. 

## Overview

HelpKit is a collection of tools for managing and presenting help articles (called topics) to the user. It supports a hierarchical directory system. Each directory gets presented to users as "groups", and supported files are shown as topics.

Currently, HelpKit supports the following kinds of documents:

- Plain Text (.txt): Renders as standard font of the app
- Rich Text (.rtf): Renders with colors, alignment, borders, etc. 
- Markdown (.md): Renders with sizes, alignment, etc.

Internally, HelpKit uses `NSAttributedString` and `AttributedString` to load and parse files. 

The center of this library is the ``HelpEngine``, an actor class that maintains an internal state of the help directory, and will load/release topics as needed. While the engine can be used outside of the UI, most of the library's functionality is for the UI. 

The UI tools are written to have lower requirements, so that they may be used on multiple platforms for the last few years of releases. 

## Topics

### Core Functionality

- ``HelpEngine``
- ``SwiftUICore/EnvironmentValues/helpEngine``

### Topics and Groups

- ``HelpResourceID``
- ``HelpResource``
- ``HelpResourcePlaceholder``
- ``HelpTopic``
- ``FileType``
- ``HelpGroup``
- ``UnloadedHelpResource``

### Fetching 

- ``LoadedHelpTopic``
- ``LoadedHelpGroup``
- ``LoadedHelpResource``
- ``TopicFetchError``
- ``GroupFetchError``
- ``ResourceLoadState``
- ``TopicLoadState``
- ``GroupLoadState``

### Presenting

- ``HelpPresenterContentProtocol``
- ``HelpResourcePresenter``
- ``TopicPresenter``
- ``TopicGroupPresenter``
- ``HelpTreePresenter``

### Attaching to the UI

- ``HelpButtonBase``
- ``TopicButton``
- ``TopicButtonStyle``
- ``TopicGroupButton``
- ``HelpToolbarButton``
- ``TopicToolbarButton``
- ``TopicGroupToolbarButton``
