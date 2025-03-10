//
//  ProcessingActor.swift
//  Swift6TestTask
//
//  Created by Siarhei Yakushevich on 07/03/2025.
//

import Foundation

final class CustomSerialExecutor: SerialExecutor {
    private let queue = DispatchQueue(label: "serial.executor.queue")
    func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        queue.async { [weak self, unownedJob] in
            guard let self else {
                return
            }
            unownedJob.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }
}
import UIKit

protocol ImageProviderType: Sendable {
    func image(at: URL) async throws -> UIImage!
}

actor ProcessingActor: ImageProviderType {
    private let executor: any SerialExecutor
    private let fileManager: FileManager
    private let imageDownloader: any NetworkImageServiceProtocol
    private let imageDirectoryURL: URL!
    
    init(executor: any SerialExecutor = CustomSerialExecutor(),
         fileManager: FileManager = .default,
         imageDownloader: any NetworkImageServiceProtocol = NetworkService()) {
        self.executor = executor
        self.fileManager = fileManager
        self.imageDownloader = imageDownloader
        imageDirectoryURL = try? Self.initContent(fileManager: fileManager)
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
    
    private func localURL(for url: URL) -> URL! {
        guard let imageDirectoryURL else {
            return nil
        }
        
        let relativePath = url.path()
        return imageDirectoryURL.appendingPathComponent(relativePath)
    }
    
    //TODO: check memory leakage..
    private func localOrRemoteImage(at url: URL) async throws -> URL {
        if let url = localURL(for: url), fileManager.fileExists(atPath: url.path()) {
            return url
        }
        return try await downloadAndCacheImage(url: url)
    }
    
    func image(at url: URL) async throws -> UIImage! {
        let url = try await localOrRemoteImage(at: url)
        return UIImage(contentsOfFile: url.path)
    }
    
    private func downloadAndCacheImage(url: URL) async throws -> URL {
        let tempURL = try await imageDownloader.downloadImageTemporary(from: url)
        assert(tempURL.isFileURL)
        
        guard let localImageURL = localURL(for: url) else {
            return tempURL
        }
        
        try? fileManager.createDirectory(at: localImageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try fileManager.copyItem(at: tempURL, to: localImageURL)
        return localImageURL
    }
    
    
    
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
}
