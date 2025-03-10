//
//  DatabaseService.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 07/03/2025.
//

import Foundation
import SwiftData

protocol CharacterListAdapter {
    func numberOfCharacterListSections() -> Int
    //func characterListSection(at: Int) -> CharactersListSectionVM!
}

actor DatabaseService /*: CharacterListAdapter*/ {
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    /*nonisolated func numberOfCharacterListSections() -> Int {
        FetchDescriptor<CharactersListDBModel.PageResult>.init(#Predicate { })
    }
    
    nonisolated func characterListSection(at: Int) -> CharactersListSectionVM! {
        
    }*/
    
    func numberOfSections() -> Int {
        0
    }
    
    private let executor = CustomSerialExecutor()
    
    private let context: ModelContext
    
    private init(container: ModelContainer) {
        //assert(!Thread.isMainThread)
        self.context = .init(container)
    }
    
    nonisolated static func create(isStoredInMemoryOnly: Bool = false) throws -> Self {
        let container = try modelContainer(isStoredInMemoryOnly: isStoredInMemoryOnly)
        
        return .init(container: container)
    }
    
    nonisolated static func modelContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            CharactersListDBModel.self,
        ])
        assert(schema.version == .init(1, 0, 0))
        
        let modelConfiguration = ModelConfiguration(schema: schema,
                                                    isStoredInMemoryOnly: isStoredInMemoryOnly)

        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        
        return container
    }
    
    
    
    
    
}
