//
//  HelpResource.swift
//  Edmund
//
//  Created by Hollan Sellars on 7/11/25.
//

import Foundation

/// An ID to use for all help resources, loaded or not.
/// This ID is constructed as a series of parts separated by '/' (from the file system).
/// It can be constructed back into a string by calling `.rawValue`, and can be parsed from any `String` instance.
/// This can be sent between threads, or saved to an encoder.
public struct HelpResourceID : Hashable, Equatable, Sendable, RawRepresentable, Codable, CustomStringConvertible {
    public typealias RawValue = String
    
    /// Constructs the blank ID, representing the root of the help tree. 
    public init() {
        self.parts = []
    }
    /// Constructs the ID from a series of pre-separated strings.
    public init(parts: [String]) {
        self.parts = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    /// Constructs the ID from a string, assumed to be a path.
    public init(rawValue: String) {
        self.parts = rawValue.split(separator: "/", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    
    /// The parts of the relative path.
    public let parts: [String];
    /// Obtains the relative path of the resource.
    public var rawValue: String {
        return parts.joined(separator: "/")
    }
    /// Obtains the last part of the ID, which is the name of the topic or group.
    public var name: String {
        if let last = parts.last {
            let subParts = last.split(separator: ".")
            if subParts.count == 1 {
                // Since we dont have any periods, we just return that name directly.
                return last
            }
            
            return subParts.dropLast().joined(separator: ".")
        }
        else {
            return "";
        }
    }
    public var description: String {
        rawValue
    }
    
    /// Appends a new string to the end of the parts, creating a new ID.
    public func appending(component: String) -> Self {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return self
        }
        
        return .init(parts: self.parts + [trimmed])
    }
    /// Appends many new strings to the end of parts, creating a new ID.
    public func appending(contentsOf: [String]) -> Self {
        let list = self.parts + contentsOf.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter{ !$0.isEmpty }
        
        return .init(parts: list)
    }
}

/// A common protocol for all unloaded and loaded HelpResources. These are values that can be sent between threads, and are identifyable using `HelpResourceID`.
public protocol HelpResource : Identifiable<HelpResourceID>, Sendable { }
public extension HelpResource {
    /// The name of the current resource
    var name: String {
        id.name
    }
}

/// A ``HelpResource`` that is unloaded, and has a specific `URL` associated to it.
public protocol HelpResourcePlaceholder : HelpResource {
    /// The location of the help resource.
    var url: URL { get }
}

/// A reference to a possibly unloaded topic, holding a file path.
public struct HelpTopic : HelpResourcePlaceholder, Sendable {
    public init(id: HelpResourceID, url: URL, content: String? = nil) {
        self.id = id
        self.url = url
        self.content = content
    }
    
    public let id: HelpResourceID;
    public let url: URL;
    /// The content of the file, if loaded.
    public var content: String?;
}

/// Represents a directory, or group of other topics or groups.
public struct HelpGroup : HelpResourcePlaceholder, Sendable {
    public init(id: HelpResourceID, url: URL, children: [HelpResourceID]) {
        self.id = id
        self.url = url
        self.children = children
    }
    
    public let id: HelpResourceID;
    public let url: URL;
    /// The children identifiers associated with this group.
    public let children: [HelpResourceID]
}

/// A wrapper around help groups and help topics
public enum UnloadedHelpResource : HelpResourcePlaceholder, Sendable {
    /// A specific topic
    case topic(HelpTopic)
    /// A specific group
    case group(HelpGroup)
    
    public var id: HelpResourceID {
        switch self {
            case .group(let g): g.id
            case .topic(let t): t.id
        }
    }
    public var url: URL {
        switch self {
            case .group(let g): g.url
            case .topic(let t): t.url
        }
    }
    /// The children of the current resource, if they exist.
    public var children: [HelpResourceID]? {
        if case .group(let g) = self {
            g.children
        }
        else {
            nil
        }
    }
    /// Determines if the current instance is a topic or not.
    public var isTopic: Bool {
        if case .topic(_) = self {
            return true
        }
        else {
            return false
        }
    }
}
