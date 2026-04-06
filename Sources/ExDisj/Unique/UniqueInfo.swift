//
//  UniqueInfo.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation

public struct UniqueIdentifierBundle : @unchecked Sendable {
    let id: ObjectIdentifier;
    let reserved: Set<AnyHashable>;
}
public struct UniqueContext : @unchecked Sendable {
    let content: [ObjectIdentifier : Set<AnyHashable>];
}
