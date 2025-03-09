//
//  CharacterListCellViewModel.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 27/02/2025.
//

import SwiftUI

extension CharactersListModel.PageInfo {
    var id: String {
        "\(next ?? "") - \(prev ?? "")"
    }
}

@Observable
final class CharactersSectionViewModel: Identifiable {
    @ObservationIgnored
    let pageInfo: CharactersListModel.PageInfo
    var characters = [CharacterListCellViewModel]()
    
    var id: String { pageInfo.id }
    
    convenience init(model: CharactersListModel) {
        self.init(pageInfo: model.info,
                  characters: model.results.map { .init(model: $0) })
    }
    
    init(pageInfo: CharactersListModel.PageInfo,
         characters: [CharacterListCellViewModel]) {
        self.pageInfo = pageInfo
        self.characters = characters
    }
}

@Observable
@MainActor
final class CharacterListCellViewModel: Identifiable {
    var imageURL: URL?
    var officialName: String = ""
    var altMessage: String?
    var frameWidth: CGFloat? = 50
    
    @ObservationIgnored
    private var retryCount = 0
    
    let model: CharactersListModel.PageResult
    nonisolated var id: Int { model.id }
    
    nonisolated init(model: CharactersListModel.PageResult) {
        self.model = model
        define()
    }
    
    private nonisolated func define() {
        Task { @MainActor in
            imageURL = model.image.flatMap { .init(string: $0) }
            officialName = model.name
        }
    }
    
    func loadedImage() {
        frameWidth = 50
    }
    
    private func refreshImageURL() {
        let old = imageURL
        imageURL = old //will refresh
    }
    
    func failedToLoadImage(error: Error) {
        debugPrint("!!! error \(error)")
        if retryCount > 2 {
            altMessage = "Failed"
            frameWidth = nil
        } else {
            retryCount += 1
            Task { @MainActor in
                try await Task.sleep(nanoseconds: 1 * 1_000_000_000) //one second...
                refreshImageURL()
            }
        }
    }
}
