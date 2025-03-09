//
//  ProcessingActor.swift
//  RedditTestTask
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

actor ProcessingActor {
    private let executor = CustomSerialExecutor()
    
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
}
