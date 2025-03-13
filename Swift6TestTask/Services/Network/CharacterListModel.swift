//
//  NetworkModels.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import Foundation

// MARK: - CharactersListModel
//TODO: remove Encodable... JSON 2 model
struct CharactersListModel: Decodable, Encodable, Sendable {
    let info: PageInfo
    let results: [PageResult]
    
    var id: String?

    // MARK: - PageInfo
    struct PageInfo: Decodable, Encodable, Sendable {
        let count, pages: Int
        let next: String?
        let prev: String?
    }
    
    // MARK: - PageThemeResult
    struct PageResult: Decodable, Encodable, Sendable {
        let id: Int
        let name: String
        let status: Status?
        let species: String?
        let type: String
        let gender: Gender?
        let origin, location: Location
        let image: String?
        let episode: [String]
        let url: String
        let created: String
    }
    
    
    enum Gender: String, Decodable, Encodable, Sendable {
        case female = "Female"
        case male = "Male"
        case unknown
        case genderless = "Genderless"
    }

    // MARK: - PageThemeLocation
    struct Location: Decodable, Encodable, Sendable {
        let name: String
        let url: String
    }

    enum Status: String, Decodable, Encodable, Sendable {
        case alive = "Alive"
        case dead = "Dead"
        case unknown
    }
}

