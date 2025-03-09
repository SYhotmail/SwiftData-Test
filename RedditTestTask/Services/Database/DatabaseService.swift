//
//  DatabaseService.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 07/03/2025.
//

import Foundation
import SwiftData

final class DatabaseService {
    
    private let context: ModelContext
    
    private init(context: ModelContext) {
        self.context = context
    }
    
    static func create(isStoredInMemoryOnly: Bool = false) throws -> Self {
        let schema = Schema([
            CharactersListDBModel.self,
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema,
                                                    isStoredInMemoryOnly: isStoredInMemoryOnly)

        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        
        return Self.init(context: .init(container))
    }
    
    
}
