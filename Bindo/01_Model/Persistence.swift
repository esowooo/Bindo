//
//  Persistence.swift
//  Bindo
//
//  Created by Sean Choi on 9/13/25.
//

import CoreData

enum Persistence {
    static let shared = make()

    static func make() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "Bindo") // 모델명
        if let d = container.persistentStoreDescriptions.first {
            d.shouldMigrateStoreAutomatically = true
            d.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { _, error in
            precondition(error == nil, "Core Data store load failed: \(String(describing: error))")
        }
        // 업서트 느낌(고유제약 충돌 시 메모리의 변경 우선)
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil
        return container
    }
}
