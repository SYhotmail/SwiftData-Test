//
//  AppContainer.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 10/03/2025.
//

import Foundation


struct AppContainer {
    let networkService = NetworkService()
    let modelContainer = try! DatabaseService.modelContainer(isStoredInMemoryOnly: false)
    let imageProvider = ProcessingActor()
}
