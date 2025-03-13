//
//  AppContainer.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 10/03/2025.
//

import Foundation


final class AppContainer {
    let networkService = NetworkService()
    let modelContainer = try! DatabaseService.modelContainer(isStoredInMemoryOnly: false)
    let imageProvider = CachedImageProvider()
    
    private lazy var database: DatabaseService = {
        return .init(container: modelContainer, imageProvider: imageProvider)
    }()
    
    @MainActor func charactersListVM() -> CharactersListVM {
        return .init(service: networkService,
                     database: database,
                     imageProvider: imageProvider)
    }
}
