//
//  DatabaseService.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 07/03/2025.
//

import Foundation
import SwiftData

protocol CharacterListAdapter {
    func lastCharactersListSection() async throws -> CharactersSectionViewModel!
}

actor DatabaseService: CharacterListAdapter {
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    private func numberOfCharacterListSections() async throws -> Int {
        try charactersListCount()
    }
    
    private let executor = CustomSerialExecutor()
    private let imageProvider: any ImageProviderType
    private var modelContext: ModelContext!
    
    init(container: ModelContainer,
         imageProvider: any ImageProviderType) {
        self.imageProvider = imageProvider
        Task {
            await defineContext(container: container)
        }
    }
    
    private func defineContext(container: ModelContainer) {
        modelContext = .init(container)
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
    
    //https://syed4asad4.medium.com/power-of-modelactor-in-swiftdata-0053651261bb
    
    func lastCharactersListSection() async throws -> CharactersSectionViewModel! {
        let count = try await numberOfCharacterListSections()
        guard count > 0 else {
            return nil
        }
        
        let vm = try charactersListModel(offset: count - 1)
        return vm.flatMap { .init(model: $0.model(), imageProvider: imageProvider) }
    }
    
    private func fetchCharactersListCore() throws -> [CharactersListDBModel] {
        let fetchDescriptor = FetchDescriptor<CharactersListDBModel>()
        return try modelContext.fetch(fetchDescriptor)
    }
    
    func fetchCharactersList() throws -> [CharactersSectionViewModel] {
        let charactersFromDB = try fetchCharactersListCore()
        return charactersFromDB.map { CharactersSectionViewModel(model: $0.model(),
                                                                 imageProvider: imageProvider) }
    }
    
    func charactersListCount(limit: Int? = nil, offset: Int? = nil) throws -> Int {
        var fetchDescriptor = FetchDescriptor<CharactersListDBModel>()
        fetchDescriptor.fetchLimit = limit
        fetchDescriptor.fetchOffset = offset
        let count = try modelContext.fetchCount(consume fetchDescriptor)
        return count
    }
    
    func charactersListModel(offset: Int? = nil) throws -> CharactersListDBModel! {
        var fetchDescriptor = FetchDescriptor<CharactersListDBModel>()
        fetchDescriptor.fetchLimit = 1
        fetchDescriptor.fetchOffset = offset
        let items = try modelContext.fetch(consume fetchDescriptor)
        return items.first
    }
    
    func hasCharactersLists() throws -> Bool {
        let limit = 1
        let count = try charactersListCount(limit: limit)
        return count <= limit && count > 0
    }
    
    func eraseCharactersListModels(save: Bool = true) throws {
        try modelContext.delete(model: CharactersListDBModel.self) //remove all...
        try saveIfNeeded(save: save)
    }
    
    func updateCharactersListModel(_ model: CharactersListModel) throws {
        
        let dbModel = CharactersListDBModel(model: model)
        modelContext.insert(dbModel)
        
        try saveIfNeeded(save: true)
    }
    
    private func saveIfNeeded(save: Bool) throws {
        if save, !modelContext.autosaveEnabled {
            try modelContext.save()
        }
    }
}
