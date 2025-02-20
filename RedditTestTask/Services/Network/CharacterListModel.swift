//
//  NetworkModels.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import Foundation

// MARK: - CharactersListModel
//TODO: remove Encodable... JSON 2 model
struct CharactersListModel: Decodable, Encodable {
    let info: PageInfo
    let results: [PageResult]

    // MARK: - PageInfo
    struct PageInfo: Decodable, Encodable {
        let count, pages: Int
        let next: String?
        let prev: String?
    }
    
    // MARK: - PageThemeResult
    struct PageResult: Decodable, Encodable {
        let id: Int
        let name: String
        let status: Status?
        let species: Species?
        let type: String
        let gender: Gender?
        let origin, location: Location
        let image: String?
        let episode: [String]
        let url: String
        let created: String
    }
    
    
    enum Gender: String, Decodable, Encodable {
        case female = "Female"
        case male = "Male"
        case unknown
    }

    // MARK: - PageThemeLocation
    struct Location: Decodable, Encodable {
        let name: String
        let url: String
    }

    enum Species: String, Decodable, Encodable {
        case alien = "Alien"
        case human = "Human"
        case unknown
    }

    enum Status: String, Decodable, Encodable {
        case alive = "Alive"
        case dead = "Dead"
        case unknown
    }
}

