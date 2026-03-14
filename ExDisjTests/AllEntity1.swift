//
//  AllEntity1.swift
//  ExDisjTests
//
//  Created by Hollan Sellars on 3/14/26.
//

import SwiftUI
import CoreData
import ExDisj

public struct AllEntity1 : View {
    @QuerySelection<Entity1> private var entities;
    
    @State private var inspect: InspectionManifest<Entity1> = .init();
    @State private var delete: DeletingManifest<Entity1> = .init();
    @State private var warning: StringWarningManifest = .init();
    
    @Environment(\.dataStack) private var dataStack;
    
    public var body: some View {
        Table(context: entities) {
            TableColumn("Name", value: \.name)
            TableColumn("Value") {
                Text($0.value, format: .number)
            }
        }.withWarning(warning)
            .withElementIE(manifest: inspect, using: dataStack, filling: { entity in
                entity.name = "";
                entity.value = 0;
            })
    }
}

#Preview {
    AllEntity1()
}
