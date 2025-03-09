//
//  CharactersListVM.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import Foundation
import SwiftUICore
@preconcurrency import Combine
import SwiftUI
import SwiftData
import Synchronization

@MainActor
@Observable //used to be Observable Object...
final class CharactersListVM /*: @unchecked Sendable*/ {
    @ObservationIgnored
    private let service: NetworkServiceProtocol
    @ObservationIgnored
    private let imageProvider: ImageProviderType
    @ObservationIgnored //ignore Publisher..
    private var cancellable = Set<AnyCancellable>()
    
    @ObservationIgnored
    var modelContext: ModelContext! {
        didSet {
            guard let modelContext, oldValue !== modelContext else {
                return
            }
            
            defineCharacters()
            /*Task {
                await defineCharacters()
            }*/
        }
    }
    
    let errorDuringLoadSubject = CurrentValueSubject<Bool,Never>(false)
    
    var errorDuringLoad: Bool {
        get {
            access(keyPath: \.errorDuringLoad)
            return errorDuringLoadSubject.value
        }
        set {
            withMutation(keyPath: \.errorDuringLoad) {
                errorDuringLoadSubject.value = newValue
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
            characterSections = charactersFromDB.map { CharactersSectionViewModel(model: $0.model(),
                                                                                  imageProvider: imageProvider) }
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
    
    init(service: NetworkServiceProtocol,
         imageProvider: ImageProviderType) {
        self.service = service
        self.imageProvider = imageProvider
        bind()
    }
    
    private let characterSectionsSubject = CurrentValueSubject<[CharactersSectionViewModel], Never>([])
    private(set)var characterSections: [CharactersSectionViewModel] {
        get {
            access(keyPath: \.characterSections)
            return characterSectionsSubject.value
        }
        set {
            withMutation(keyPath: \.characterSections) {
                characterSectionsSubject.value = newValue
            }
        }
    }
    
    let searchableTextSubject = CurrentValueSubject<String, Never>("")
    private(set)var searchableText: String {
        get {
            access(keyPath: \.searchableText)
            return searchableTextSubject.value
        }
        set {
            withMutation(keyPath: \.searchableText) {
                searchableTextSubject.value = newValue
            }
        }
    }
    
    private let isLoadingSubject = CurrentValueSubject<Bool?, Never>(nil)
    private(set)var isLoading: Bool? {
        get {
            access(keyPath: \.isLoading)
            return isLoadingSubject.value
        }
        set {
            withMutation(keyPath: \.isLoading) {
                isLoadingSubject.value = newValue
            }
        }
    }
    
    private let errorLoadingMessageSubject = CurrentValueSubject<String?,Never>(nil)
    private(set)var errorLoadingMessage: String? {
        get {
            access(keyPath: \.errorLoadingMessage)
            return errorLoadingMessageSubject.value
        }
        set {
            withMutation(keyPath: \.errorLoadingMessage) {
                errorLoadingMessageSubject.value = newValue
            }
        }
    }
    
    var filteredCharacterSections: [CharactersSectionViewModel]!
    
    @ObservationIgnored
    private var task: Task<Void, Never>!
    @ObservationIgnored
    private let loadingURL = Mutex<URL?>(nil)
    @ObservationIgnored
    private let loadedURL = Mutex<URL??>(nil)
    
    private func bind() {
        errorLoadingMessageSubject.map { $0?.isEmpty == false } //CurrentValueSubject, used to be: $errorLoadingMessage
            .receive(on: DispatchQueue.main)
            .subscribe(errorDuringLoadSubject)
            .store(in: &cancellable)
        
        characterSectionsSubject.combineLatest(searchableTextSubject.removeDuplicates())
            .dropFirst()
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .map { [unowned self] sections, text  in
                guard !text.isEmpty else {
                    return sections
                }
                //TODO: add filtering inside sections.....
                let filteredSections = sections.filter { $0.characters.contains(where: { $0.officialName.lowercased().contains(text.lowercased()) }) }
                guard !filteredSections.isEmpty else {
                    return []
                }
                
                
                return filteredSections.map { filteredSection in CharactersSectionViewModel(imageProvider: self.imageProvider,
                                                                                            pageInfo: filteredSection.pageInfo,
                                                                                            characters: filteredSection.characters.filter { $0.officialName.lowercased().contains(text.lowercased()) }) }
                
            }
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] filteredCharacterSections in
                self.filteredCharacterSections = filteredCharacterSections
            }.store(in: &cancellable)
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
    
    nonisolated private func loadCharactersPageAsync(url: URL?, eraseOld: Bool = false) async {
        
        Task { @MainActor in
            isLoading = true
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
            let section = CharactersSectionViewModel(model: backendSection,
                                                     imageProvider: imageProvider)
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
        
        Task { @MainActor in
            self.errorLoadingMessage = errorLoadingMessage
            isLoading = false
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
            //debugPrint("!!! \(#function) nextURL \(nextURL) prevURL \(prevURL)")
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
        assert(Thread.isMainThread)
        //disposeTask()
    }
}


extension CurrentValueSubject {
    typealias TranscationVoidBlock = @Sendable (Transaction) -> Void
    func binding(transactionBlock: TranscationVoidBlock? = nil) -> Binding<Output> {
        binding(transactionBlock: transactionBlock, defaultValue: value)
    }
    
    func binding(transactionBlock: TranscationVoidBlock? = nil, defaultValue: Output) -> Binding<Output> {
        let res = Binding<Output?>{ [weak self] in
            self?.value
        } set: { [weak self] (value, transaction) in
            if let value {
                self?.send(value)
            }
            transactionBlock?(transaction)
        }
        
        return .init(res) ?? .constant(defaultValue)
    }
}
