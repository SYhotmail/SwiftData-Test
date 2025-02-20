//
//  CharactersPageDBModel.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import Foundation
import SwiftData

protocol ModelConvertable {
    associatedtype ModelType
    init(model: ModelType)
    func model() -> ModelType
}


// MARK: - PageThemeCharacters
@Model
final class CharactersListDBModel: ModelConvertable {
    var info: PageInfo
    var results: [PageResult]
    
    init(info: PageInfo, results: [PageResult]) {
        self.info = info
        self.results = results
    }
    
    convenience init(model: CharactersListModel) {
        self.init(info: .init(model: model.info),
                  results: model.results.map { .init(model: $0) })
    }
    
    func model() -> CharactersListModel {
        .init(info: info.model(),
              results: results.map { $0.model() })
    }
    
    // MARK: - PageInfo
    @Model
    final class PageInfo: ModelConvertable {
        @Attribute(.unique) var count: Int
        var pages: Int
        var next: String?
        var prev: String?
        
        init(count: Int,
             pages: Int,
             next: String?,
             prev: String?) {
            self.count = count
            self.pages = pages
        }
        
        convenience init(model: CharactersListModel.PageInfo) {
            self.init(count: model.count,
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
        var name: String
        var status: CharactersListModel.Status?
        var species: CharactersListModel.Species?
        var type: String
        var gender: CharactersListModel.Gender?
        var origin: CharactersListModel.Location
        var location: CharactersListModel.Location
        var image: String?
        //var episode: [String]
        var url: String
        var created: String
        
        init(id: Int, name: String, status: CharactersListModel.Status?, species: CharactersListModel.Species?, type: String, gender: CharactersListModel.Gender?, origin: CharactersListModel.Location, location: CharactersListModel.Location, image: String?, episode: [String], url: String, created: String) {
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
