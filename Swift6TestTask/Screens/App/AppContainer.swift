//
//  AppContainer.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 10/03/2025.
//

import Foundation
import SwiftData


final class AppContainer: @unchecked Sendable {
    let networkService: NetworkService
    
    let imageProvider: CachedImageProvider
    private var database: DatabaseService!
    let modelContainer: ModelContainer
    
    init() {
        let networkService = NetworkService()
        self.networkService = networkService
        self.modelContainer = try! DatabaseService.modelContainer(isStoredInMemoryOnly: false)
        imageProvider = CachedImageProvider(imageDownloader: networkService)
        
        
        Task { //TODO: Improve...
            assert(!Thread.isMainThread)
            database = .init(modelContainer: try! DatabaseService.modelContainer(isStoredInMemoryOnly: false))
            await database.setImageProvider(imageProvider)
        }
    }
    
    @MainActor func charactersListVM() -> CharactersListVM {
        return .init(service: networkService,
                     database: database,
                     imageProvider: imageProvider)
    }
}
