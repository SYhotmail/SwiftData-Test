//
//  Swift6TestTaskApp.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import SwiftUI
import SwiftData

@main
struct Swift6TestTaskApp: App {
    @State var container = AppContainer()
    
    var body: some Scene {
        WindowGroup {
            CharactersListView().environment(container.charactersListVM())
        }
        .modelContainer(container.modelContainer)
    }
}
