//
//  RedditTestTaskApp.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import SwiftUI
import SwiftData

@main
struct RedditTestTaskApp: App {
    @State var networkService = NetworkService()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CharactersListDBModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            CharactersListView().environment(CharactersListVM(service: networkService))
        }
        .modelContainer(sharedModelContainer)
    }
}
