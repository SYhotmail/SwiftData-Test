//
//  CharactersListVM.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import Foundation
import SwiftUICore
import Combine
import SwiftUI
import SwiftData

final class CharactersListVM: ObservableObject, @unchecked Sendable {
    let service: NetworkServiceProtocol
    private var cancellable = Set<AnyCancellable>()
    
    var modelContext: ModelContext! {
        didSet {
            guard let modelContext, oldValue !== modelContext else {
                return
            }
            
            Task { @MainActor in
                defineCharacters()
            }
        }
    }
    
    @MainActor
    private func defineCharacters() {
        guard let modelContext else {
            return
        }
        
        let fetchDescriptor = FetchDescriptor<CharactersListDBModel>()
        if let charactersFromDB = try? modelContext.fetch(fetchDescriptor) {
            self.characterSections = charactersFromDB.map { CharactersSectionViewModel(model: $0.model()) }
        }
    }
    
    @MainActor
    func updateCharacters(model: CharactersListModel) {
        guard let modelContext else {
            return
        }
        
        let fetchDescriptor = FetchDescriptor<CharactersListDBModel>()
        if let charactersFromDB = try? modelContext.fetch(fetchDescriptor) {
            charactersFromDB.forEach { dbModel in
                modelContext.delete(dbModel)
            }
        }
        
        let dbModel = CharactersListDBModel(model: model)
        modelContext.insert(dbModel)
        
        try? modelContext.save()
    }
    
    init(service: NetworkServiceProtocol) {
        self.service = service
        bind()
    }
    
    let charactersFromDBSubject = CurrentValueSubject<[CharactersListDBModel], Never>([])
    
    @Published private var characterSections = [CharactersSectionViewModel]()
    @MainActor @Published var isLoading: Bool?
    @MainActor @Published var errorLoadingMessage: String?
    @MainActor @Published var errorDuringLoad = false
    @MainActor @Published var searchableText: String = ""
    
    @MainActor @Published var filteredCharacterSections = [CharactersSectionViewModel]()
    
    private func bind() {
        $errorLoadingMessage.map { $0?.isEmpty == false }
            .assign(to: &$errorDuringLoad)
        
        $characterSections.combineLatest($searchableText.removeDuplicates())
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .map { section, text  in
                guard !text.isEmpty else {
                    return section
                }
                //TODO: add filtering inside sections.....
                return section.filter { $0.characters.contains(where: {  $0.officialName.contains(text)}) }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$filteredCharacterSections)
    }
    
    func loadCharactersAsync() async {
        
        Task { @MainActor [weak self] in
            self?.isLoading = true
        }
        
        var errorLoadingMessage: String?
        do {
            assert(!Thread.isMainThread)
            var lastSection = await MainActor.run { [weak self] in self?.characterSections.last }
            //TODO: add support for pagination...
            lastSection = nil
            let backendSection = try await service.getAllCharacters(pageInfo: lastSection.flatMap { $0.pageInfo })
            Task { @MainActor in
                updateCharacters(model: backendSection)
            }
            
            let section = CharactersSectionViewModel(model: backendSection)
            Task { @MainActor [section] in
                self.characterSections = [section] //TODO: add pagination support and use query from database...
            }
            
        } catch {
            errorLoadingMessage = error.localizedDescription
        }
        
        Task { @MainActor [weak self, errorLoadingMessage] in
            self?.errorLoadingMessage = errorLoadingMessage
            self?.isLoading = false
        }
    }
    
    
    func loadCharacters() {
        Task(priority: .userInitiated) {
            await self.loadCharactersAsync()
        }
    }
}
