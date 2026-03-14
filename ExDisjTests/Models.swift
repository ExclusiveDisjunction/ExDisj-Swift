//
//  Models.swift
//  ExDisjTests
//
//  Created by Hollan Sellars on 3/14/26.
//

import CoreData

public extension Entity1 {
    var name: String {
        get { self.internalName ?? String() }
        set { self.internalName = newValue }
    }
}
