//
//  Evil_Master_PlanApp.swift
//  Evil Master Plan
//
//  Created by Jürgen Reichardt-Kron on 07.04.26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct Evil_Master_PlanApp: App {
    var body: some Scene {
        DocumentGroup(editing: .itemDocument, migrationPlan: Evil_Master_PlanMigrationPlan.self) {
            ContentView()
        }
    }
}

extension UTType {
    static var itemDocument: UTType {
        UTType(importedAs: "com.example.item-document")
    }
}

struct Evil_Master_PlanMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [
        Evil_Master_PlanVersionedSchema.self,
    ]

    static var stages: [MigrationStage] = [
        // Stages of migration between VersionedSchema, if required.
    ]
}

struct Evil_Master_PlanVersionedSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        Item.self,
    ]
}
