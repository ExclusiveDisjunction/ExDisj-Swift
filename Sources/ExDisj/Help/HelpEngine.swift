//
//  HelpEngine.swift
//  Edmund
//
//  Created by Hollan Sellars on 7/10/25.
//

import Foundation
import SwiftUI
import os

/// A type that allows for the location of help resources, provided to the ``HelpEngine``.
public protocol HelpResourcesLocator {
    static func locate() -> URL?;
}

/// A ``HelpResourcesLocator`` that uses the "Help" directory of the package's resources.
public struct DefaultHelpResourcesLocator : HelpResourcesLocator {
    private init() { }
    
    public static func locate() -> URL? {
        Bundle.main.url(forResource: "Help", withExtension: nil)
    }
}

/// A universal system to index, manage, cache, and produce different help topics & groups over some physical directory.
public actor HelpEngine {
    /// Constructs the engine, unloaded, providing a logger.
    ///
    /// This will not load the information, one must call ``walkDirectory(locator:)`` or ``walkDirectory(baseURL:)`` to load all articles.
    public init(_ logger: Logger? = nil) {
        self.logger = logger
        self.data = .init()
    }
    
    /// Walks a directory, inserting all elements it finds into the engine, and returns all direct resource ID's for children notation.
    private func walkDirectory(topID: HelpResourceID, url: URL) async -> [HelpResourceID]? {
        let fileManager = FileManager.default
        guard let resource = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
            return nil;
        }
        
        var result: [HelpResourceID] = [];
        
        if let isDirectory = resource.isDirectory, isDirectory {
            guard let enumerator = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else {
                return nil
            }
            
            for case let path in enumerator {
                let newId = topID.appending(component: path.lastPathComponent);
                result.append(newId)
                
                if let resource = try? path.resourceValues(forKeys: [.isDirectoryKey]), let isDirectory = resource.isDirectory, isDirectory {
                    guard let children = await self.walkDirectory(topID: newId, url: path) else {
                        continue
                    }
                    
                    self.data[newId] = .group(
                        HelpGroup(
                            id: newId,
                            url: path,
                            children: children
                        )
                    )
                }
                else {
                    self.data[newId] = .topic(
                        HelpTopic(
                            id: newId,
                            url: path
                        )
                    )
                }
            }
        }
        
        return result
    }
    
    /// Walks the default pacakge help directory, recording all groups (folders) and topics (files) it finds.
    @discardableResult
    public func walkDirectory<L>(locator: L.Type) async -> Bool
    where L: HelpResourcesLocator {
        guard let url = locator.locate() else {
            print("Unable to find help content base directory.")
            return false
        }
        
        return await self.walkDirectory(baseURL: url)
    }
    
    /// Walks a specific base URL, recording all groups (folders) and topics (files) it finds.
    @discardableResult
    public func walkDirectory(baseURL url: URL) async -> Bool {
        logger?.info("Starting help engine walk of directory \(url, privacy: .private)")
        let rootId = HelpResourceID(parts: [])
        //The root must be written in the data as a TopicGroup, so the directory must be walked.
        guard let children = await self.walkDirectory(topID: rootId, url: url) else {
            return false
        }
        
        self.data[rootId] = .group(
            HelpGroup(
                id: rootId,
                url: url,
                children: children
            )
        )
        
        self.walked = true
        logger?.info("Help engine walk is complete.")
        return true
    }
    
    /// The internal logger used for the help engine.
    private let logger: Logger?;
    /// Represents the engine being unloaded. When false, retreiving data returns .notLoaded.
    private var walked: Bool = false;
    /// The root ID from the top of the directory.
    private var rootId: HelpResourceID = .init(parts: [])
    /// All topics and groups recognized by the engine.
    private var data: [HelpResourceID : UnloadedHelpResource]
    /// The ID of values that have been cached.
    private var cache: LimitedQueue<HelpResourceID> = .init(capacity: 50, with: .init(parts: []));
    
    /// Instructs the engine to wipe all data.
    public func reset() async {
        logger?.info("Help engine was asked to reset")
        if !walked { return }
        
        self.walked = false
        self.data = [:]
        self.cache.clear()
    }
    
    /// Ensures that the cache is not too full.
    private func registerCache(id: HelpResourceID) {
        logger?.info("HelpEngine is caching id \(id)")
        if let oldId = cache.append(id) {
            //Get the old element
            
            guard let first = data[oldId], case .topic(var oldTopic) = first else {
                // Didnt resolve correctly, but that is ok
                return;
            }
            
            // Unload the data and update the internal data
            oldTopic.content = nil;
            self.data[oldId] = .topic(oldTopic)
        }
    }
    
    /// Obtains a topic out of the cache, if loaded. Otherwise, it will load it and optionally cahce it.
    /// - Parameters:
    ///     - topic: The target topic to load.
    ///     - cache: Instructs the engine to cache the loaded result if it must load it.
    /// - Throws: Any error that `String(contentsOf:encoding:)` throws while loading the file contents.
    private func getOrLoadTopic(topic: HelpTopic, cache: Bool = true) async throws -> LoadedHelpTopic {
        let topicContent: String;
        if let content = topic.content {
            logger?.debug("The topic was cached, returning that value")
            topicContent = content;
        }
        else {
            logger?.debug("The topic was not cached, loading and then registering cache.")
            let url = topic.url;
            topicContent = try await Task(priority: .medium) {
                return try String(contentsOf: url, encoding: .utf8)
                }.value
            
            if cache {
                var topic = topic;
                self.registerCache(id: topic.id)
                topic.content = topicContent
                data[topic.id] = .topic(topic) //Update with new content
            }
            
            
        }
        
        return LoadedHelpTopic(id: topic.id, content: topicContent)
    }
    /// Simply loads the topic's files, without doing checks and deep logging.
    /// - Parameters:
    ///     - id: The resource ID to load.
    /// - Throws: ``TopicFetchError`` if the `id` points to a group, or if the contents could not be loaded.
    private func getTopicDirect(id: HelpResourceID) async throws(TopicFetchError) -> LoadedHelpTopic {
        guard let resx = data[id] else {
            logger?.error("The requested topic was not found.")
            throw .notFound
        }
        
        guard case .topic(let topic) = resx else {
            logger?.error("The requested topic was actually a group")
            throw .isAGroup
        }
        
        do {
            return try await self.getOrLoadTopic(topic: topic, cache: false)
        }
        catch let e {
            throw .fileReadError(e.localizedDescription)
        }
    }
    
    /// Loads a topic from the engine from a specified `HelpResourceID`.
    /// If the topic could not be found/resolved correctly, or the engine is loading, this will throw an error.
    /// - Parameters:
    ///     - id: The specified ID of the topic to load.
    /// - Returns:
    ///     - A ``LoadedHelpTopic``, containing all topic information.
    /// - Throws: ``TopicFetchError`` if the `id` points to a group, the contents could not be loaded, or the engine has not been loaded.
    public func getTopic(id: HelpResourceID) async throws(TopicFetchError) -> LoadedHelpTopic {
        logger?.info("Topic \(id) has been requested")
        guard walked else {
            logger?.error("Topic requested before the engine has completed loading.")
            throw .engineLoading
        }
        
        guard let resx = data[id] else {
            logger?.error("The requested topic was not found.")
            throw .notFound
        }
        
        guard case .topic(let topic) = resx else {
            logger?.error("The requested topic was actually a group")
            throw .isAGroup
        }
        
        do {
            return try await self.getOrLoadTopic(topic: topic)
        }
        catch let e {
            throw .fileReadError(e.localizedDescription)
        }
    }
    
    /// Loads a topic from the engine and deposits the information into a `TopicLoadHandle`.
    ///
    /// Any errors occuring from the engine will be placed as `.error()` in the `deposit` handle. See ``getTopic(id:)`` for more information about errors.
    /// - Parameters:
    ///     - id: The ID of the topic to load.
    ///     - deposit: The specified handle (id and status updater) to load the resources from the engine.
    public func getTopic(id: HelpResourceID, deposit: Binding<TopicLoadState>) async {
        await MainActor.run {
            withAnimation {
                deposit.wrappedValue = .loading
            }
        }
        
        let result: LoadedHelpTopic;
        do {
            result = try await self.getTopic(id: id)
        }
        catch let e {
            await MainActor.run {
                withAnimation {
                    deposit.wrappedValue = .error(e)
                }
            }
            
            return
        }
        
        await MainActor.run {
            withAnimation {
                deposit.wrappedValue = .loaded(result)
            }
        }
    }
    
    /// Using `data` and some ``HelpGroup``, this will walk the tree and resolve all children into a ``LoadedHelpResource`` package.
    /// This function is self-recursive, as it walks the entire tree structure starting at `group`.
    /// - Parameters:
    ///     - group: The root node to start walking from
    /// - Returns:
    ///     - All children under `group`, as loaded resources.
    /// - Throws: ``TopicFetchError`` if the group could not be walked, any sub-topic could not be loaded, or the engine is not loaded.
    private func walkGroup(group: HelpGroup) async throws(TopicFetchError) -> [LoadedHelpResource] {
        var result: [LoadedHelpResource] = [];
        for child in group.children {
            guard let resolved = data[child] else {
                 //Could not resolve the id, so we just move on
                continue;
            }
            
            switch resolved {
                case .group(let g):
                    let children = try await self.walkGroup(group: g)
                    result.append(
                        .group(LoadedHelpGroup(id: g.id, children: children))
                    )
                case .topic(let t):
                    let loaded = try await self.getTopicDirect(id: t.id)
                    result.append(
                        .topic(loaded)
                    )
            }
        }
        
        return result
    }
    /// Loads a group from the engine from a specified `HelpResourceID`.
    /// - Parameters:
    ///     - id: The specified ID of the group to load.
    /// - Returns:
    ///     - A `LoadedHelpGroup` instance with information to load all children resources.
    /// - Throws: ``GroupFetchError`` if the engine is not loaded, any sub-topic could not be loaded, or the group could not be walked.
    public func getGroup(id: HelpResourceID) async throws(GroupFetchError) -> LoadedHelpGroup {
        logger?.info("Loading group with id \(id)")
        guard walked else {
            logger?.error("A group was requested before the help engine has loaded")
            throw .engineLoading
        }
        
        guard let resx = data[id] else {
            logger?.error("The group with id \(id) was not found.")
            throw .notFound
        }
        
        guard case .group(let group) = resx else {
            logger?.error("The group with id \(id) was actually a topic.")
            throw .isATopic
        }
        
        logger?.debug("Walking group.")
        //From this point on, we have the group, we need to resolve all children recursivley.
        let children: [LoadedHelpResource];
        do {
            children = try await self.walkGroup(group: group);
        }
        catch let e {
            throw .topicLoad(e)
        }
        
        let root = LoadedHelpGroup(id: id, children: children);
        
        return root;
    }
    
    /// Loads a group from the engine and deposits the information into a  binding.
    /// Any errors occuring from the engine will be placed as `.error()` in the `deposit` handle. See ``getGroup(id:)`` for more information on errors.
    /// - Parameters:
    ///     - id: The ID of the group to load.
    ///     - deposit: The specified handle (id and status updater) to load the resources from the engine.
    public func getGroup(id: HelpResourceID, deposit: Binding<GroupLoadState>) async {
        await MainActor.run {
            withAnimation {
                deposit.wrappedValue = .loading
            }
        }
        
        let result: LoadedHelpGroup;
        do {
            result = try await self.getGroup(id: id)
        }
        catch {
            await MainActor.run {
                withAnimation {
                    deposit.wrappedValue = .error(error)
                }
            }
            
            return
        }
        
        await MainActor.run {
            withAnimation {
                deposit.wrappedValue = .loaded(result)
            }
        }
    }
    
    /// Loads the entire engine's tree, and returns the top level resources.
    /// See the documentation for ``getGroup(id:)`` for information about errors.
    public func getTree() async throws(GroupFetchError) -> LoadedHelpGroup {
        try await self.getGroup(id: rootId)
    }
    /// Loads the engire engine's tree and places the result into a `WholeTreeLoadHandle`, as updates occur.
    /// - Parameters:
    ///     - deposit: The location to send updates about the fetch to.
    public func getTree(deposit: Binding<GroupLoadState>) async {
        await self.getGroup(id: self.rootId, deposit: deposit)
    }
}

fileprivate struct HelpEngineKey : EnvironmentKey {
    public typealias Value = HelpEngine;
    
    public static var defaultValue: HelpEngine {
        .init()
    }
}

public extension EnvironmentValues {
    /// Access the loaded help engine. 
    var helpEngine: HelpEngine {
        get { self[HelpEngineKey.self] }
        set { self[HelpEngineKey.self] = newValue }
    }
}
