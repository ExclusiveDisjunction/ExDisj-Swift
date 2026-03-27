//
//  ContainerDescription.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/27/26.
//

import SwiftData
@preconcurrency import CoreData
import Foundation

public struct ContainerDescription<Container> : Sendable where Container: ContainerProtocol {
    public let schemaLocator: @Sendable () async throws -> Container.SchemaDesc;
    public let stores: @Sendable () throws -> [StoreDescription];
    public let onLoad: (@Sendable (Container.Context) throws -> Void)?;
}
