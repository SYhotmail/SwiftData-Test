//
//  CharactersPageDBModel.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import Foundation
import SwiftData
import CoreData

protocol ModelConvertable {
    associatedtype ModelType
    init(model: ModelType)
    func model() -> ModelType
}


// MARK: - PageThemeCharacters
@Model
final class CharactersListDBModel: ModelConvertable {
    @Relationship(deleteRule: .cascade) var info: PageInfo
    
    @Relationship(deleteRule: .cascade) var results: [PageResult]
    
    @Attribute(.unique) var id: String
    
    private init(id: String?,
                 info: PageInfo, results: [PageResult]) {
        self.id = id ?? info.id
        self.info = info
        self.results = results
        
        bindRelationships()
    }
    
    convenience init(model: CharactersListModel) {
        self.init(id: model.id,
                  info: .init(model: model.info),
                  results: model.results.map { .init(model: $0) })
    }
    
    private func bindRelationships() {
        info.charactersListDBModel = self
        results.forEach { $0.charactersListDBModel = self }
    }
    
    func model() -> CharactersListModel {
        .init(info: info.model(),
              results: results.map { $0.model() })
    }
    
    // MARK: - PageInfo
    @Model
    final class PageInfo: ModelConvertable {
        var count: Int
        var pages: Int
        
        var next: String?
        var prev: String?
        
        @Relationship(inverse: \CharactersListDBModel.info) var charactersListDBModel: CharactersListDBModel?
        
        var id: String
        
        init(id: String,
             count: Int,
             pages: Int,
             next: String?,
             prev: String?) {
            self.count = count
            self.pages = pages
            self.prev = prev
            self.next = next
            self.id = id
        }
        
        convenience init(model: CharactersListModel.PageInfo) {
            self.init(id: model.id,
                      count: model.count,
                      pages: model.pages,
                      next: model.next,
                      prev: model.prev)
        }
        
        func model() -> CharactersListModel.PageInfo {
            .init(count: count,
                  pages: pages,
                  next: next,
                  prev: prev)
        }
    }
    
    // MARK: - PageThemeResult
    @Model
    final class PageResult: ModelConvertable {
        @Attribute(.unique) var id: Int
        
        @Relationship(inverse: \CharactersListDBModel.results) var charactersListDBModel: CharactersListDBModel?
        
        @Attribute(.spotlight)
        var name: String
        
        @Transient
        var nameFirstLetter: String {
            guard let ch = name.first else {
                assertionFailure("No name!")
                return ""
            }
            return String(ch)
        }
        
        var status: CharactersListModel.Status?
        var species: String?
        var type: String
        var gender: CharactersListModel.Gender?
        var origin: CharactersListModel.Location
        var location: CharactersListModel.Location
        var image: String?
        //var episode: [String]
        var url: String
        var created: String
        
        init(id: Int,
             name: String,
             status: CharactersListModel.Status?,
             species: String?,
             type: String,
             gender: CharactersListModel.Gender?,
             origin: CharactersListModel.Location,
             location: CharactersListModel.Location,
             image: String?,
             episode: [String],
             url: String,
             created: String) {
            self.id = id
            self.name = name
            self.status = status
            self.species = species
            self.type = type
            self.gender = gender
            self.origin = origin
            self.location = location
            self.image = image
            //self.episode = episode
            self.url = url
            self.created = created
        }
        
        convenience init(model: CharactersListModel.PageResult) {
            self.init(id: model.id,
                      name: model.name,
                      status: model.status,
                      species: model.species,
                      type: model.type,
                      gender: model.gender,
                      origin: model.origin,
                      location: model.location,
                      image: model.image,
                      episode: [], //model.episode, - FIXME: CoreData: Could not materialize Objective-C c
                      url: model.url,
                      created: model.created)
        }
        
        func model() -> CharactersListModel.PageResult {
            .init(id: id,
                      name: name,
                      status: status,
                      species: species,
                      type: type,
                      gender: gender,
                      origin: origin,
                      location: location,
                      image: image,
                      episode: [],//episode,
                      url: url,
                      created: created)
        }
    }
}
