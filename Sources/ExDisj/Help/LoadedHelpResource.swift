//
//  LoadedHelpResource.swift
//  Edmund
//
//  Created by Hollan Sellars on 7/11/25.
//

import Foundation

/// Represents a topic that is guarenteed to have a file content.
public struct LoadedHelpTopic : HelpResource, Sendable {
    /// Constructs the resource around an ID and `String` content.
    ///
    /// - Warning: This is intended to be constructed by the ``HelpEngine``. See ``HelpEngine/getTopic(id:)``.
    internal init(id: HelpResourceID, content: String) {
        self.id = id
        self.content = content
    }
    
    public let id: HelpResourceID;
    /// The topic's file content
    public let content: String;
}

/// A complete tree with topic requests for presenting on the user interface.
public struct LoadedHelpGroup : HelpResource, Identifiable, Sendable {
    /// Constructs the resource around an ID and ``LoadedHelpResource`` content.
    ///
    /// - Warning: This is intended to be constructed by the ``HelpEngine``. See ``HelpEngine/getTopic(id:)``.
    internal init(id: HelpResourceID, children: [LoadedHelpResource]) {
        self.id = id
        self.children = children
    }
    
    public let id: HelpResourceID;
    /// The children groups and topics of the current group.
    public let children: [LoadedHelpResource];
    
    /// Searches for a loaded help resource under the current group. This is recursive.
    /// - Parameters:
    ///     - id: The ID of the resource to search for.
    /// - Returns: The ``LoadedHelpResource`` matching the `id`, if such a resource exists.
    public func findChild(id: HelpResourceID) -> LoadedHelpResource? {
        for child in children {
            if child.id == id {
                return child
            }
            
            if case .group(let g) = child {
                if let result = g.findChild(id: id) {
                    return result
                }
            }
        }
        
        return nil
    }
    
    /// Returns all children resources that are topics.
    public var topicChildren: [LoadedHelpTopic] {
        children.compactMap {
            if case .topic(let t) = $0 { return t } else { return nil }
        }
    }
    /// Returns all children resources that are groups.
    public var groupChildren: [LoadedHelpGroup] {
        children.compactMap {
            if case .group(let t) = $0 { return t } else { return nil }
        }
    }
}

/// Either a ``LoadedHelpTopic`` or a ``LoadedHelpGroup`` instance for presenting on the UI.
public enum LoadedHelpResource : HelpResource, Sendable, Identifiable {
    /// A loaded help topic
    case topic(LoadedHelpTopic)
    /// A loaded help group
    case group(LoadedHelpGroup)
    
    public var id: HelpResourceID {
        switch self {
            case .topic(let t): t.id
            case .group(let g): g.id
        }
    }
    /// The children groups/topics associated with this current instance.
    public var children: [LoadedHelpResource]? {
        if case .group(let g) = self {
            g.children
        }
        else {
            nil
        }
    }
}
