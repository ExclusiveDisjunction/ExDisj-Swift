//
//  UniqueEnforcer.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation

public protocol UniqueEnforcer : Actor {
    func fetchAll() async throws -> UniqueContext;
    var state: UniqueEngineState? { get set }
}
extension UniqueEnforcer {
    public func withState(state: UniqueEngineState?) {
        self.state = state;
    }
}

public actor SimpleUniqueEnforcer : UniqueEnforcer {
    public var state: UniqueEngineState?;
    
    public func fetchAll() -> UniqueContext {
        return .init(content: [:])
    }
}

