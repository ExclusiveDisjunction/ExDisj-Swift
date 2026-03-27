//
//  Filler.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/27/26.
//

/// A type that can be used to fill in dummy data for a specific container's context.
public protocol ContainerDataFiller : Sendable {
    associatedtype Container: ContainerProtocol;
    
    /// Given the `context`, fill out the container's values.
    /// - Parameters:
    ///     - context: The `NSManagedObjectContext` to insert to.
    func fill(context: Container.Context) throws;
}

