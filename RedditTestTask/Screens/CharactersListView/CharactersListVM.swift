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
import Synchronization

//TODO: - ObservationIgnored
// @Observable
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
    private func eraseDatabase(save: Bool = true) throws {
        guard let modelContext else {
            return
        }
        
        let fetchDescriptor = FetchDescriptor<CharactersListDBModel>()
        let charactersFromDB = try modelContext.fetch(fetchDescriptor)
        
        charactersFromDB.forEach { dbModel in
            modelContext.delete(dbModel)
        }
        
        if save, !modelContext.autosaveEnabled {
            try modelContext.save()
        }
    }
    
    @MainActor
    func updateCharacters(model: CharactersListModel) throws {
        guard let modelContext else {
            return
        }
        
        let dbModel = CharactersListDBModel(model: model)
        modelContext.insert(dbModel)
        
        try modelContext.save()
    }
    
    init(service: NetworkServiceProtocol) {
        self.service = service
        bind()
    }
    
    @Published private(set)var characterSections = [CharactersSectionViewModel]()
    @MainActor @Published var isLoading: Bool?
    @MainActor @Published var errorLoadingMessage: String?
    @MainActor @Published var errorDuringLoad = false
    @MainActor @Published var searchableText: String = ""
    
    @MainActor @Published var filteredCharacterSections = [CharactersSectionViewModel]()
    
    private var task: Task<Void, Never>!
    private let loadingURL = Mutex<URL?>(nil)
    private let loadedURL = Mutex<URL??>(nil)
    
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
    
    private func isLoadingSameCharactersPage(url: URL?) -> Bool {
        !Task.isCancelled && loadingURL.withLock { $0 } == url
    }
    
    private func markAsFinishedLoading(result: Result<URL?, Error>) {
        loadingURL.withLock { $0 = nil }
        if let url = try? result.get() {
            loadedURL.withLock { urlPtr in
                urlPtr = .some(url)
            }
        }
    }
    
    private func loadCharactersPageAsync(url: URL?, eraseOld: Bool = false) async {
        
        Task { @MainActor in
            self.isLoading = true
        }
        
        var errorLoadingMessage: String?
        do {
            assert(!Thread.isMainThread)
            self.loadingURL.withLock {
               $0 = url
            }
            
            let backendSection = try await service.getAllCharacters(url: url)
            debugPrint("!!! backendSection.pageInfo \(backendSection.info)")
            debugPrint("!!! ids \(backendSection.results.map { $0.id })")
            let section = CharactersSectionViewModel(model: backendSection)
            Task { @MainActor [section, backendSection] in
                guard isLoadingSameCharactersPage(url: url) else {
                    return
                }
                
                assert(eraseOld || characterSections.last?.pageInfo.next == url?.absoluteString)
                if eraseOld {
                    characterSections = []
                }
                characterSections.append(section)
                markAsFinishedLoading(result: .success(url))
                //TODO: how to change or update?
                if eraseOld {
                    try eraseDatabase(save: false)
                }
                try updateCharacters(model: backendSection)
            }
        } catch {
            errorLoadingMessage = error.localizedDescription
        }
        
        Task { @MainActor [errorLoadingMessage] in
            self.errorLoadingMessage = errorLoadingMessage
            self.isLoading = false
        }
    }
    
    func reloadCharacters(once: Bool = false) {
        guard !(once && characterSections.isEmpty) || task == nil || loadedURL.withLock({ $0 }) == nil else {
            return
        }
        loadCharactersPage(force: true)
    }
    
    func lastSectionRowId() -> Int? {
        lastInSectionRowId(index: characterSections.count - 1)
    }
    
    func lastInSectionRowId(index: Int) -> Int? {
        guard characterSections.count > index, index >= 0 else {
            return nil
        }
        
        let section = characterSections[index]
        return section.characters.last?.id
    }
    
    func willAppear(characterVM character: CharacterListCellViewModel) {
        if character.id == lastSectionRowId() {
            loadCharactersPage(force: false)
        }
    }
    
    @MainActor func isLoadingAndLastRow(characterVM character: CharacterListCellViewModel) -> Bool {
        isLoading == true && character.id == lastSectionRowId()
    }
    
    
    @discardableResult
    func loadCharactersPage(force: Bool) -> Bool {
        var url: URL?
        var run = force
        if force {
            url = nil
            debugPrint("!!! \(#function) ")
        } else {
            let nextURLRaw = characterSections.last.flatMap { $0.pageInfo.next }
            let nextURL = nextURLRaw.flatMap { URL(string: $0) }
            
            let prevURLRaw = characterSections.last.flatMap { $0.pageInfo.prev }
            let prevURL = prevURLRaw.flatMap { URL(string: $0) }
            debugPrint("!!! \(#function) nextURL \(nextURL) prevURL \(prevURL)")
            run = (loadingURL.withLock({ $0 }) != nextURL && loadedURL.withLock({ $0 }) != prevURL)
            url = nextURL
        }
        
        guard run else {
            return false
        }
        disposeTask()
        
        task = Task(priority: .userInitiated) { [url] in
            await loadCharactersPageAsync(url: url, eraseOld: force)
        }
        return true
    }
    
    private func disposeTask() {
        if let task, !task.isCancelled {
            if !task.isCancelled {
                task.cancel()
            }
            self.task = nil
        }
        markAsFinishedLoading(result: .success(nil))
    }
    
    deinit {
        disposeTask()
    }
}
