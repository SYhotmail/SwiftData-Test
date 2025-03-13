//
//  CharacterListCellViewModel.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 27/02/2025.
//

import SwiftUI
import SectionedQuery

extension CharactersListModel.PageInfo {
    var id: String {
        "\(next ?? "") - \(prev ?? "")"
    }
}

@Observable
final class CharactersSectionViewModel: Identifiable, Sendable {
    @ObservationIgnored
    let pageInfo: CharactersListModel.PageInfo
    @ObservationIgnored
    let characters: [CharacterListCellViewModel]
    
    let imageProvider: any ImageProviderType
    var id: String { pageInfo.id }
    
    convenience init(model: CharactersListModel,
                     imageProvider: any ImageProviderType) {
        let results = model.results
        self.init(imageProvider: imageProvider,
                  pageInfo: model.info,
                  characters: results.enumerated().map { .init(model: $0.element,
                                                               imageProvider: imageProvider) })
    }
    
    init(imageProvider: any ImageProviderType,
         pageInfo: CharactersListModel.PageInfo,
         characters: [CharacterListCellViewModel]) {
        self.imageProvider = imageProvider
        self.pageInfo = pageInfo
        self.characters = characters
    }
}

@Observable
final class CharacterListCellViewModel: Identifiable, Sendable {
    private let imageURL: URL?
    let officialName: String
    
    @ObservationIgnored
    let imageProvider: any ImageProviderType
    
    @MainActor
    private(set)var isLoading = false
    
    @MainActor
    private(set)var altMessage: String?
    @MainActor
    private(set)var frameWidth: CGFloat? = 50
    
    @MainActor
    private(set)var localImage: UIImage?
    
    @MainActor
    private var retryCount = 0
    
    @MainActor
    private var isVisible: Bool?
    
    let id: Int
    
    init(model: CharactersListModel.PageResult,
         imageProvider: any ImageProviderType) {
        id = model.id
        imageURL = model.image.flatMap { .init(string: $0) }
        officialName = model.name
        self.imageProvider = imageProvider
    }
    
    @MainActor
    func onAppear() async {
        guard let imageURL, localImage == nil else {
            return
        }
        
        do {
            isVisible = nil
            isLoading = true
            let localImage = try await imageProvider.image(at: imageURL)
            if isVisible != false {
                frameWidth = 50
                self.localImage = localImage //if hidden then reset...
            }
        }
        catch {
            failedToLoadImage(error: error)
        }
        isLoading = false
    }
    
    @MainActor
    func onDissappear() {
        localImage = nil
        isVisible = false
    }
    
    @MainActor
    func onAppear() {
        isVisible = true
    }
    
    @MainActor
    var imageCanBeLoaded: Bool {
        imageURL.flatMap { _ in retryCount < 3 } == true
    }
    
    @MainActor
    func reload() {
        guard !isLoading else {
            return
        }
        
        if !imageCanBeLoaded {
            retryCount = 0
        }
        Task {
            await onAppear()
        }
    }
    
    @MainActor
    private func failedToLoadImage(error: Error) {
        debugPrint("!!! error \(error)")
        guard imageCanBeLoaded else {
            altMessage = "Failed"
            frameWidth = nil
            return
        }
        
        retryCount += 1
        Task {
            try await Task.sleep(nanoseconds: 1 * 1_000_000_000) //one second...
            await onAppear()
        }
    }
}
