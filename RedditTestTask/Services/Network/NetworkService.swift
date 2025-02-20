//
//  NetworkService.swift
//  RedditTestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import Foundation

enum NetworkError: Error {
    case invalidResponse(URLResponse)
    case error(any Error)
    case invalidInputPageInfo(CharactersListModel.PageInfo)
}

protocol NetworkServiceProtocol: Sendable {
    func getAllCharacters(pageInfo: CharactersListModel.PageInfo?) async throws(NetworkError) -> CharactersListModel
    func getAllCharacters() async throws(NetworkError) -> CharactersListModel
}

extension NetworkServiceProtocol {
    func getAllCharacters() async throws(NetworkError) -> CharactersListModel {
        try await getAllCharacters(pageInfo: nil)
    }
}

struct NetworkService: NetworkServiceProtocol {
    
    let urlSession: URLSession
    let baseURL: URL
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        baseURL = URL(string: "https://rickandmortyapi.com/api")! // /all")
    }
    
    func getAllCharacters(pageInfo: CharactersListModel.PageInfo?) async throws(NetworkError) -> CharactersListModel {
        
        let finalURL: URL
        //?fields=name,capital,flags
        if let pageInfo {
            guard let next = pageInfo.next, let url = URL(string: next) else {
                throw NetworkError.invalidInputPageInfo(pageInfo)
            }
            finalURL = url
            assert(finalURL.absoluteString.hasPrefix(baseURL.absoluteString)) // is it always like that?
        } else {
            finalURL = baseURL.appendingPathComponent("character")
        }
        do {
            let tuple = try await urlSession.data(for: .init(url: finalURL))
            guard let response = tuple.1 as? HTTPURLResponse, response.statusCode == 200 else {
                throw NetworkError.invalidResponse(tuple.1)
            }
            
            //try await Task.sleep(nanoseconds: 6_000_000_000)
            
            let data = tuple.0
            
            return try JSONDecoder().decode(CharactersListModel.self, from: data)
        }
        catch {
            debugPrint("!!! \(error)")
            throw NetworkError.error(error)
        }
        
    }
}
