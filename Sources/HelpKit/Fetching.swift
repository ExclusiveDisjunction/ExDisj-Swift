//
//  Fetching.swift
//  Edmund
//
//  Created by Hollan Sellars on 7/12/25.
//

import Observation
import Combine

/// An error representing what can go wrong when fetching a `HelpTopic` instance into a `LoadedHelpTopic` instance.
public enum TopicFetchError : Error, Sendable {
    case notFound
    case isAGroup
    case fileReadError(any Error)
    case engineLoading
    case unsupportedFileType(String)
    
    public var localizedDescription: String {
        switch self {
            case .notFound: "The specified resource could not be found"
            case .isAGroup: "The specified resource is a group, but a topic was expected"
            case .fileReadError(let e): "The file could not be read due to error \(e.localizedDescription)"
            case .engineLoading: "The Help Engine is currently loading, and cannot access resources"
            case .unsupportedFileType(let ext): "The topic pointed to a file of type \(ext), but it is not supported"
        }
    }
}
/// An error representing what can go wrong when fetching a `HelpGroup` instance into a `LoadedHelpGroup` instance.
public enum GroupFetchError : Error, Sendable {
    case notFound
    case isATopic
    case engineLoading
    case topicLoad(TopicFetchError)
}

/// A status system used to indicate the stage in which a resource (`T`) gets fetched.
/// Includes information about any errors, stored as `E`.
public enum ResourceLoadState<T, E> where E: Sendable, E: Error {
    case loading
    case loaded(T)
    case error(E)
}
extension ResourceLoadState : Sendable where T: Sendable { }

/// The load state for help topics.
public typealias TopicLoadState = ResourceLoadState<LoadedHelpTopic, TopicFetchError>;
/// The load state for help groups.
public typealias GroupLoadState = ResourceLoadState<LoadedHelpGroup, GroupFetchError>;
