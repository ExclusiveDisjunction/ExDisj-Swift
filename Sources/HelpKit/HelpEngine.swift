//
//  HelpEngine.swift
//  Edmund
//
//  Created by Hollan Sellars on 7/10/25.
//

import Foundation
import SwiftUI
import os
import ExDisj

/// An indication of what type of file, corresponding by extension, a file is.
public enum FileType : String, Sendable, Hashable, Equatable, Codable {
    /// The file is markdown.
    case markdown = "md"
    /// The file is rich text format.
    case richText = "rtf"
    /// The file is a plain text file.
    case plain = "txt"
}

/// An error that can occur while walking the help directory.
public enum WalkError : Error {
    /// The engine expected a directory, but was given a file.
    case expectedDirectoryGotFile
    /// The engine was not able to find an enumerator for a directory.
    case noFileEnumerator
    /// The engine was not given a base directory.
    case noBaseDirectory
}

/// A universal system to index, manage, cache, and produce different help topics & groups over some physical directory.
public final actor HelpEngine {
    /// Constructs the engine, unloaded, providing a logger.
    ///
    /// This will not walk any directories, and will contain only an empty state. You must walk the engine to load resources. Any attempt to access a resource before walking will result in an error.
    public init(_ logger: Logger? = nil) {
        self.logger = logger
        self.data = .init()
    }
    
    /// Walks a directory, inserting all elements it finds into the engine, and returns all direct resource ID's for children notation.
    private func walkDirectory(topID: HelpResourceID, url: URL, fileManager: FileManager) async throws(WalkError) -> [HelpResourceID] {
        guard let resource = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
            throw WalkError.expectedDirectoryGotFile;
        }
        
        var result: [HelpResourceID] = [];
        
        if let isDirectory = resource.isDirectory, isDirectory {
            guard let enumerator = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else {
                throw .noFileEnumerator;
            }
            
            for case let path in enumerator {
                let newId = topID.appending(component: path.lastPathComponent);
                result.append(newId)
                
                if let resource = try? path.resourceValues(forKeys: [.isDirectoryKey]), let isDirectory = resource.isDirectory, isDirectory {
                    let children = try await self.walkDirectory(topID: newId, url: path, fileManager: fileManager);
                    
                    self.data[newId] = .group(
                        HelpGroup(
                            id: newId,
                            url: path,
                            children: children
                        )
                    )
                }
                else {
                    guard let fileType = FileType(rawValue: path.pathExtension) else {
                        logger?.info("Resource \(newId) has an invalid file type (\(path.pathExtension)), and will be skipped");
                        continue;
                    }
                    
                    self.data[newId] = .topic(
                        HelpTopic(
                            id: newId,
                            url: path,
                            type: fileType
                        )
                    )
                }
            }
        }
        
        return result
    }
    
    /// Walks the directory provided by `locateUsing`.
    /// - Parameters:
    ///     - fileManager: The `FileManager` to use for enumerating directories.
    ///     - locator: A closure that returns the URL to walk.
    /// - Throws: Any error that `locateUsing` or ``walkDirectory(baseURL:fileManager:)`` throws.
    /// - Warning: This call will perform all directory walking on the current thread. Ensure that the actor does not run on the main actor. By default, this actor is background thread isolated.
    ///
    /// If no error is thrown, the engine completed its walk, and can load resources.
    public func walkDirectory(fileManager: FileManager, locateUsing locator: () async throws -> URL?) async throws {
        guard let url = try await locator() else {
            logger?.error("Unable to find the help content base directory.")
            throw WalkError.noBaseDirectory;
        }
        
        return try await self.walkDirectory(baseURL: url, fileManager: fileManager)
    }
    /// Walks the directory indicated in the Resources folder of `bundle`, with the name `rootDirName`.
    /// - Parameters:
    ///     - fileManager: The `FileManager` to use for enumerating directories.
    ///     -  bundle: The `Bundle` to look into for resources.
    ///     - name: The name of the directory to notate as the "help-root"
    /// - Throws: Any error that ``walkDirectory(baseURL:fileManager:)`` throws.
    /// - Warning: This call will perform all directory walking on the current thread. Ensure that the actor does not run on the main actor. By default, this actor is background thread isolated.
    ///
    /// If no error is thrown, the engine completed its walk, and can load resources.
    public func walkDirectory(fileManager: FileManager, bundle: Bundle, rootDirName name: String) async throws(WalkError) {
        do {
            try await walkDirectory(fileManager: fileManager) {
                bundle.url(forResource: name, withExtension: nil)
            };
        }
        catch let e as WalkError {
            throw e
        }
        catch let e {
            fatalError("Unexpected error from walkDirectory(baseURL:fileManager:), \(e)")
        }
    }
    /// Walks the directory indicated in the Resources folder of `bundle`, with the name `rootDirName`.
    /// - Parameters:
    ///     - url: The URL to notate as the "help-root"
    ///     - fileManager: The `FileManager` to use for enumerating directories.
    /// - Throws: While walking the directory, if internal expectaions are not met, it will throw ``WalkError``. These are rare events, and should be recorded.
    /// - Warning: This call will perform all directory walking on the current thread. Ensure that the actor does not run on the main actor. By default, this actor is background thread isolated.
    ///
    /// If no error is thrown, the engine completed its walk, and can load resources.
    public func walkDirectory(baseURL url: URL, fileManager: FileManager) async throws(WalkError) {
        self.reset();
        
        logger?.info("Starting help engine walk of directory \(url, privacy: .private)")
        let rootId = HelpResourceID(parts: [])
        
        //The root must be written in the data as a TopicGroup, so the directory must be walked.
        let children = try await self.walkDirectory(topID: rootId, url: url, fileManager: fileManager)
        
        self.data[rootId] = .group(
            HelpGroup(
                id: rootId,
                url: url,
                children: children
            )
        )
        
        self.walked = true
        logger?.info("Help engine walk is complete.")
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
    public func reset() {
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
    
    /// Obtains a topic out of the cache, if loaded. Otherwise, it will load it and optionally cache it.
    /// - Parameters:
    ///     - topic: The target topic to load.
    ///     - cache: Instructs the engine to cache the loaded result if it must load it.
    /// - Throws: Any error that occurs while loading the file.
    private func getOrLoadTopic(topic: HelpTopic, cache: Bool = true) async throws -> LoadedHelpTopic {
        let topicContent: AttributedString;
        if let content = topic.content {
            logger?.debug("The topic was cached, returning that value")
            topicContent = content;
        }
        else {
            logger?.debug("The topic was not cached, loading and then registering cache.")
            let url = topic.url;
            
            
            guard let fileType = FileType(rawValue: url.pathExtension) else {
                throw TopicFetchError.unsupportedFileType(url.pathExtension)
            }
            
            let contents: NSAttributedString;
            switch fileType {
                case .richText: fallthrough
                case .plain:
                    var options: [NSAttributedString.DocumentReadingOptionKey : Any] = [:];
                    if fileType == .richText {
                        options[.documentType] = NSAttributedString.DocumentType.rtf;
                    }
                    else {
                        options[.documentType] = NSAttributedString.DocumentType.plain;
                    }
                    
                    contents = try NSAttributedString(url: url, options: options, documentAttributes: nil)
                case .markdown:
                    contents = try NSAttributedString(contentsOf: url)
            }

            topicContent = AttributedString(contents);
            
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
            throw .fileReadError(e)
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
            throw .fileReadError(e)
        }
    }
    
    /// Loads a topic from the engine and deposits the information into a `TopicLoadHandle`.
    ///
    /// Any errors occuring from the engine will be placed as `.error()` in the `deposit` handle. See ``getTopic(id:)`` for more information about errors.
    /// - Parameters:
    ///     - id: The ID of the topic to load.
    ///     - deposit: The specified handle (id and status updater) to load the resources from the engine.
    ///
    /// The provided `deposit` is regarded as MainActor bound. This means that all operations to update it are done using the MainActor.
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
    /// The provided `deposit` is regarded as MainActor bound. This means that all operations to update it are done using the MainActor.
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
    
    /// Loads the entire engine's root, and returns all fetched results.
    /// See the documentation for ``getGroup(id:)`` for information about errors.
    public func getTree() async throws(GroupFetchError) -> LoadedHelpGroup {
        try await self.getGroup(id: rootId)
    }
    /// Loads the engire engine's root.
    /// - Parameters:
    ///     - deposit: The location to send updates about the fetch to.
    /// The provided `deposit` is regarded as MainActor bound. This means that all operations to update it are done using the MainActor.
    public func getTree(deposit: Binding<GroupLoadState>) async {
        await self.getGroup(id: self.rootId, deposit: deposit)
    }
}

public extension EnvironmentValues {
    /// Access the ``HelpEngine`` passed through the environment.
    @Entry var helpEngine: HelpEngine = HelpEngine()
}
