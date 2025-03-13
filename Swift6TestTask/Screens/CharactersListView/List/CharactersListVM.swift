//
//  CharactersListVM.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import Foundation
import SwiftUICore
@preconcurrency import Combine
import SwiftUI
import SwiftData
import Synchronization
import SectionedQuery

@MainActor
@Observable //used to be Observable Object...
final class CharactersListVM {
    @ObservationIgnored
    private let service: any NetworkServiceProtocol
    @ObservationIgnored
    let imageProvider: any ImageProviderType
    
    @ObservationIgnored
    let database: DatabaseService
    
    @ObservationIgnored //ignore Publisher..
    private var cancellable = Set<AnyCancellable>()
    
    @ObservationIgnored
    private var listId: String = ""
    
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
    
    private func fetchCharactersList() async throws -> [CharactersSectionViewModel] {
        try await database.fetchCharactersList()
    }
    
    private func eraseCharactersListModels(save: Bool = true) async throws {
        try await database.eraseCharactersListModels(save: save)
    }
    
    private func updateCharactersListModel(_ model: CharactersListModel) async throws {
        try await database.updateCharactersListModel(model)
    }
    
    init(service: any NetworkServiceProtocol,
         database: DatabaseService,
         imageProvider: any ImageProviderType) {
        self.service = service
        self.database = database
        self.imageProvider = imageProvider
        bind()
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

    @ObservationIgnored
    private let loadingURL = Mutex<URL?>(nil)
    @ObservationIgnored
    private let loadedURL = Mutex<URL??>(nil)
    
    private func bind() {
        searchableTextSubject.removeDuplicates().map { $0 }.eraseToAnyPublisher().sink { [unowned self] in
            //Self.searchText = $0
            self.listId = $0 //to refresh query...
        }.store(in: &cancellable)
        
        errorLoadingMessageSubject.map { $0?.isEmpty == false } //CurrentValueSubject, used to be: $errorLoadingMessage
            .receive(on: DispatchQueue.main)
            .subscribe(errorDuringLoadSubject)
            .store(in: &cancellable)
        
        searchableText = Self.searchText
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
    
    private func lastCharacterSection() async throws -> CharactersSectionViewModel! {
      try await database.lastCharactersListSection()
    }
    
    private func loadCharactersPageAsync(url: URL, eraseOld: Bool = false) async {
        
        Task { @MainActor in
            isLoading = true
        }
        
        var errorLoadingMessage: String?
        do {
            //assert(!Thread.isMainThread)
            self.loadingURL.withLock {
               $0 = url
            }
            
            let backendSection = try await service.getAllCharacters(url: url)
            debugPrint("!!! backendSection.pageInfo \(backendSection.info)")
            debugPrint("!!! ids \(backendSection.results.map { $0.id })")
            
            Task { @MainActor [backendSection] in
                guard isLoadingSameCharactersPage(url: url) else {
                    return
                }
                
                //assert(eraseOld || (try? lastCharacterSection())?.pageInfo.next == url?.absoluteString)
                if eraseOld {
                    try await eraseCharactersListModels(save: false)
                }
                try await updateCharactersListModel(backendSection)
                
                markAsFinishedLoading(result: .success(url))
                //TODO: how to change or update?
                
            }
        } catch {
            errorLoadingMessage = error.localizedDescription
            markAsFinishedLoading(result: .failure(error))
        }
        
        Task { @MainActor in
            self.errorLoadingMessage = errorLoadingMessage
            isLoading = false
        }
    }
    
    @MainActor
    func reloadCharacters(once: Bool = false) async {
        let isNotEmpty = (try? await database.hasCharactersLists()) == true
        guard !once || isNotEmpty || loadedURL.withLock({ $0 }) == nil else {
            return
        }
        await loadCharactersPage(force: true)
    }
    
    func listCellVM(item: CharactersListDBModel.PageResult) -> CharacterListCellViewModel {
        return .init(model: item.model(),
                    imageProvider: imageProvider)
    }
    
    func willAppear(characterVM character: CharacterListCellViewModel) async {
        await loadCharactersPage(force: false)
    }
    
    nonisolated static private(set)var searchText: String {
        get {
            UserDefaults.standard.string(forKey: "searchText") ?? ""
        }
        set {
            //TODO: filtering is happens on view level, i.e. when view is recreated...
            UserDefaults.standard.set(newValue, forKey: "searchText")
        }
    }
    
    static func sectionedQuery() -> SectionedQuery<String, CharactersListDBModel.PageResult> {
        let lowerText = searchText
        return .init(\.nameFirstLetter,
                      filter: lowerText.isEmpty ? nil : #Predicate<CharactersListDBModel.PageResult> { $0.name.contains(lowerText) },
                      sort: [SortDescriptor(\.name)])
    }
    
    func isLastCharacter(_ character: CharactersListDBModel.PageResult,
                         sections: SectionedResults<String, CharactersListDBModel.PageResult>) -> Bool {
        guard let last = sections.last else {
            return false
        }
        let isLast = last.lastIndex(of: character) == last.count - 1
        return isLast
    }
    
    func noSearchableText(sections: SectionedResults<String, CharactersListDBModel.PageResult>) -> Bool {
        sections.isEmpty && !searchableText.isEmpty
    }
    
    @discardableResult
    func loadCharactersPage(force: Bool) async -> Bool {
        var url = service.charactersFirstPageURL()
        var run = force
        if force {
            debugPrint("!!! \(#function) ")
        } else if let section = try? await lastCharacterSection() {
            let nextURLRaw = section.pageInfo.next
            let nextURL = nextURLRaw.flatMap { URL(string: $0) }
            
            let prevURLRaw = section.pageInfo.prev
            let prevURL = prevURLRaw.flatMap { URL(string: $0) }
            //debugPrint("!!! \(#function) nextURL \(nextURL) prevURL \(prevURL)")
            run = (loadingURL.withLock({ $0 }) != nextURL && loadedURL.withLock({ $0 }) != prevURL)
            if let nextURL {
                url = nextURL
            }
            
            if run {
                run = loadingURL.withLock({ $0 }) != url && loadedURL.withLock({ $0 }) != url
            }
        }
        
        guard run else {
            return false
        }
        await loadCharactersPageAsync(url: url, eraseOld: force) //TODO: adjust...
        
        return true
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
