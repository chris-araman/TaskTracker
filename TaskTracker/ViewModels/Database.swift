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
    var accountStatus: CKAccountStatus { get }
    var tasks: [Task] { get }

    func save(_ task: CKRecord) async throws
    func delete(_ tasks: [CKRecord.ID]) async throws
}

class CloudKitDatabase: Database, ObservableObject {
    @Published var accountStatus = CKAccountStatus.couldNotDetermine
    @Published var tasks = [Task]()

    private let container = CKContainer.default()
    private let database: CCKDatabase

    init() {
        self.database = container.privateCloudDatabase
        container.accountStatus().catch { _ in Just(.couldNotDetermine) }.assign(to: &$accountStatus)
        _Concurrency.Task.detached {
            do {
                try await self.fetchAll()
            }
            catch {
                // TODO: Handle failure
                print("Failed: \(error)")
            }
        }
    }

    func fetchAll() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.performQuery(ofType: "Task")
                .receive(on: RunLoop.main)
                .collect()
                .map { records in
                    continuation.resume()
                    return records.map { record in
                        Task(from: record)
                    }
                }
                .catch { error -> AnyPublisher<[Task], Never> in
                    continuation.resume(throwing: error)
                    return Just(self.tasks).eraseToAnyPublisher()
                }
                .assign(to: &$tasks)
        }
    }

    func save(_ task: CKRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.save(record: task)
                .receive(on: RunLoop.main)
                .map { record in
                    continuation.resume()
                    var tasks = self.tasks
                    tasks.append(Task(from: record))
                    return tasks
                }
                .catch { error -> AnyPublisher<[Task], Never> in
                    continuation.resume(throwing: error)
                    return Just(self.tasks).eraseToAnyPublisher()
                }
                .assign(to: &$tasks)
        }
    }

    func delete(_ tasks: [CKRecord.ID]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.delete(recordIDs: tasks)
                .receive(on: RunLoop.main)
                .map { recordID in
                    continuation.resume()

                    var tasks = self.tasks
                    tasks.removeAll { task in
                        task.record.recordID == recordID
                    }

                    return tasks
                }
                .catch { error -> AnyPublisher<[Task], Never> in
                    continuation.resume(throwing: error)
                    return Just(self.tasks).eraseToAnyPublisher()
                }
                .assign(to: &$tasks)
        }
    }
}
