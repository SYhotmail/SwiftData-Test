//
//  ProcessingActor.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 07/03/2025.
//

import Foundation
import UIKit

protocol ImageProviderType: Sendable {
    func image(at: URL) async throws -> UIImage!
}

final class LocalImageCacher: @unchecked Sendable {
    let fileManager: FileManager
    let imageDirectoryURL: URL
    
    init?(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        guard let imageDirectoryURL = try? Self.initContent(fileManager: fileManager) else {
            return nil
        }
        self.imageDirectoryURL = imageDirectoryURL
    }
    
    private static func initContent(fileManager: FileManager) throws -> URL! {
        let urls = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)
        guard let downloadsURL = urls.last else {
            return nil
        }
        let directoryURL = downloadsURL.appending(components: "cache", "images",
                                                  directoryHint: .isDirectory)
        if !fileManager.fileExists(atPath: directoryURL.path()) {
            try fileManager.createDirectory(at: directoryURL,
                                            withIntermediateDirectories: true)
            
        }
        return directoryURL
    }
    
    private func localURL(for url: URL) -> URL {
        let relativePath = url.path()
        return imageDirectoryURL.appendingPathComponent(relativePath)
    }
    
    func localURLForExistingFile(for url: URL) -> URL? {
        let url = localURL(for: url)
        guard fileManager.fileExists(atPath: url.path()) else {
            return nil
        }
        return url
    }
    
    func cacheTempFile(url tempURL: URL) throws -> URL {
        let localImageURL = localURL(for: tempURL)
        
        try? fileManager.createDirectory(at: localImageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try fileManager.copyItem(at: tempURL, to: localImageURL)
        return localImageURL
    }
}

final class CachedImageProvider: ImageProviderType {
    private let imageDownloader: any NetworkImageServiceProtocol
    private let imageCacher: LocalImageCacher!
    
    init(imageDownloader: any NetworkImageServiceProtocol = NetworkService(),
         imageCacher: LocalImageCacher! = .init()) {
        self.imageDownloader = imageDownloader
        self.imageCacher = imageCacher
    }
    
    private func localOrRemoteImage(at url: URL) async throws -> URL {
        if let url = imageCacher?.localURLForExistingFile(for: url) {
            return url
        }
        return try await downloadAndCacheImage(url: url)
    }
    
    func image(at url: URL) async throws -> UIImage! {
        debugPrint("!!! \(#function) url: \(url)")
        let localURL = try await localOrRemoteImage(at: url)
        assert(FileManager.default.fileExists(atPath: localURL.path()))
        return UIImage(contentsOfFile: localURL.path)
    }
    
    private func downloadAndCacheImage(url: URL) async throws -> URL {
        let tempURL = try await imageDownloader.downloadImageTemporary(from: url)
        assert(tempURL.isFileURL)
        
        return try imageCacher?.cacheTempFile(url: tempURL) ?? tempURL
    }
}
