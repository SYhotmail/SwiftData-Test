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
final class CharacterListCellViewModel: Identifiable {
    var imageURL: URL?
    var officialName: String
    var altMessage: String?
    var frameWidth: CGFloat? = 50
    
    @ObservationIgnored
    private var retryCount = 0
    
    let model: CharactersListModel.PageResult
    var id: Int { model.id }
    
    init(model: CharactersListModel.PageResult) {
        self.model = model
        imageURL = model.image.flatMap { .init(string: $0) }
        officialName = model.name
    }
    
    func loadedImage() {
        frameWidth = 50
    }
    
    @MainActor
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
                try await Task.sleep(nanoseconds: 1000_000 * 1_000_000_000) // sleep for millisecond.....
                refreshImageURL()
            }
        }
    }
}
