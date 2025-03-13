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
    private func numberOfCharacterListSections() async throws -> Int {
        try charactersListCount()
    }
    
    private var imageProvider: (any ImageProviderType)!
    
    func setImageProvider(_ provider: any ImageProviderType) {
        imageProvider = provider
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
    
    func lastCharactersListSection() async throws -> CharactersSectionViewModel! {
        let vm = try charactersListModel(order: .reverse)
        return vm.flatMap { .init(model: $0.model(), imageProvider: imageProvider) }
    }
    
    private func fetchCharactersListCore() throws -> [CharactersListDBModel] {
        assert(!Thread.isMainThread)
        let fetchDescriptor = charactersListFetchDescriptor()
        return try modelContext.fetch(fetchDescriptor)
    }
    
    func fetchCharactersList() throws -> [CharactersSectionViewModel] {
        let charactersFromDB = try fetchCharactersListCore()
        return charactersFromDB.map { CharactersSectionViewModel(model: $0.model(),
                                                                 imageProvider: imageProvider) }
    }
    
    private func charactersListFetchDescriptor(limit: Int? = nil,
                                               offset: Int? = nil,
                                               order: SortOrder = .forward) -> FetchDescriptor<CharactersListDBModel> {
        var fetchDescriptor = charactersListFetchDescriptor(CharactersListDBModel.self)
        fetchDescriptor.sortBy = [.init(\.id,
                                         order: order)]
        assert(!Thread.isMainThread)
        return fetchDescriptor
    }
    
    private func charactersListFetchDescriptor<T: PersistentModel>(_ type: T.Type,
                                                                   limit: Int? = nil,
                                                                   offset: Int? = nil) -> FetchDescriptor<T> {
        var fetchDescriptor = FetchDescriptor<T>()
        fetchDescriptor.fetchLimit = limit
        fetchDescriptor.fetchOffset = offset
        return fetchDescriptor
    }
    
    func charactersListCount(limit: Int? = nil, offset: Int? = nil) throws -> Int {
        let fetchDescriptor = charactersListFetchDescriptor(limit: limit,
                                                            offset: offset)
        let count = try modelContext.fetchCount(consume fetchDescriptor)
        return count
    }
    
    func charactersListModel(offset: Int? = nil,
                             order: SortOrder) throws -> CharactersListDBModel! {
        assertIsolated()
        assert(!Thread.isMainThread)
        let fetchDescriptor = charactersListFetchDescriptor(limit: 1,
                                                            offset: offset,
                                                            order: order)
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
    
    
    nonisolated let modelExecutor: any SwiftData.ModelExecutor
    
    nonisolated let modelContainer: SwiftData.ModelContainer
    let executor = CustomSerialExecutor()
    
    init(modelContainer: SwiftData.ModelContainer) {
        assert(!Thread.isMainThread)
        let modelContext = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
        self.modelContainer = modelContainer
    }
    
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        return .init(ordinary: executor)
    }
}

extension DatabaseService: SwiftData.ModelActor {
}

final class CustomSerialExecutor: SerialExecutor {
    private let queue = DispatchQueue(label: "serial.executor.queue")
    func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        queue.async { [weak self, unownedJob] in
            guard let self else {
                return
            }
            unownedJob.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }
}
