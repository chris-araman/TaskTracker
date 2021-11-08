//
//  Database.swift
//  TaskTracker
//
//  Created by Chris Araman on 8/31/21.
//

import CloudKit
import Combine
import CombineCloudKit
import SwiftUI

private struct DatabaseEnvironmentKey: EnvironmentKey {
    static let defaultValue: Database = CloudKitDatabase()
}

extension EnvironmentValues {
    var database: Database {
        get { self[DatabaseEnvironmentKey.self] }
        set { self[DatabaseEnvironmentKey.self] = newValue }
    }
}

extension View {
    func database(_ database: Database) -> some View {
        environment(\.database, database)
    }
}

protocol Database {
    func save(_ task: Task) async throws
}

class CloudKitDatabase: Database, ObservableObject {
    private let database: CCKDatabase = CKContainer.default().privateCloudDatabase
    private var cancellables = Set<AnyCancellable>()

    func save(_ task: Task) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.save(record: task.record)
                .receive(on: RunLoop.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                            return
                        }

                        continuation.resume()
                    },
                    receiveValue: { value in
                        print("Task added! \(task)")
                    }
                )
                // FIXME: Is this cancellable stored indefinitely?
                .store(in: &cancellables)
        }
    }
}
