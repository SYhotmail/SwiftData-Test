//
//  NetworkService.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 17/02/2025.
//

import Foundation

enum NetworkError: Error {
    case invalidResponse(URLResponse)
    case error(any Error)
    case invalidInputPageInfo(CharactersListModel.PageInfo)
    case invalidParameter(String)
}

protocol NetworkServiceProtocol: Sendable {
    func getAllCharacters(url: URL) async throws(NetworkError) -> CharactersListModel
    func getAllCharacters() async throws(NetworkError) -> CharactersListModel
    nonisolated func charactersFirstPageURL() -> URL
}

protocol NetworkImageServiceProtocol: Sendable {
    func downloadImageTemporary(from url: URL) async throws(NetworkError) -> URL
}

extension NetworkServiceProtocol {
    func getAllCharacters() async throws(NetworkError) -> CharactersListModel {
        try await getAllCharacters(url: charactersFirstPageURL())
    }
}

struct NetworkService: NetworkServiceProtocol {
    let urlSession: URLSession
    let baseURL: URL
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        baseURL = URL(string: "https://rickandmortyapi.com/api")! // /all")
    }
    
    nonisolated func charactersFirstPageURL() -> URL {
        baseURL.appendingPathComponent("character").appending(queryItems: [.init(name: "page", value: "1")])
    }
    
    func getAllCharacters(url finalURL: URL) async throws(NetworkError) -> CharactersListModel {
        debugPrint("!!! \(#function) url \(finalURL)")
        assert(finalURL.absoluteString.hasPrefix(baseURL.absoluteString)) // is it always like that?
        do {
            let tuple = try await urlSession.data(for: .init(url: finalURL))
            guard let response = tuple.1 as? HTTPURLResponse, response.statusCode == 200 else {
                throw NetworkError.invalidResponse(tuple.1)
            }
            let data = tuple.0
            
            var result = try JSONDecoder().decode(CharactersListModel.self, from: data)
            result.id = finalURL.query()
            debugPrint("!!! result \(result.info.id)")
            return result
        }
        catch {
            debugPrint("!!! \(error)")
            throw NetworkError.error(error)
        }
        
    }
}

extension NetworkService: NetworkImageServiceProtocol {
    func downloadImageTemporary(from url: URL) async throws(NetworkError) -> URL {
        do {
            let request = URLRequest(url: url)
            let tuple = try await urlSession.download(for: request)
            
            guard let response = tuple.1 as? HTTPURLResponse, response.statusCode == 200 else {
                throw NetworkError.invalidResponse(tuple.1)
            }
            let url = tuple.0
            return url
        }
        catch {
            debugPrint("!!! \(error)")
            throw NetworkError.error(error)
        }
    }
}
