//
//  Database.swift
//  TaskTracker
//
//  Created by Chris Araman on 11/30/21.
//

import CloudKit
import Combine
import CombineCloudKit

protocol DatabaseService {
  func accountStatus() async -> CKAccountStatus
  func fetchAll() async throws -> [Task]
  func save(_ task: Task) async throws
  func delete(_ tasks: [Task.ID]) async throws
}

class CloudKitDatabaseService: DatabaseService {
  private let container = CKContainer.default()
  private var database: CCKDatabase {
    container.privateCloudDatabase
  }

  func accountStatus() async -> CKAccountStatus {
    await withCancellableContinuation { continuation in
      container.accountStatus()
        .catch { _ in
          Just(.couldNotDetermine)
        }
        .sink { status in
          continuation.resume(returning: status)
        }
    }
  }

  func fetchAll() async throws -> [Task] {
    try await withCancellableThrowingContinuation { continuation in
      database.performQuery(ofType: "Task")
        .map { record in
          Task(from: record)
        }
        .collect()
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
            }
          },
          receiveValue: { tasks in
            continuation.resume(returning: tasks)
          }
        )
    }
  }

  func save(_ task: Task) async throws {
    try await withCancellableThrowingContinuation { continuation in
      database.save(record: task.record)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
              return
            }

            continuation.resume()
          },
          receiveValue: { _ in }
        )
    }
  }

  func delete(_ tasks: [Task.ID]) async throws {
    try await withCancellableThrowingContinuation { continuation in
      database.delete(recordIDs: tasks)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
              return
            }

            continuation.resume()
          },
          receiveValue: { _ in }
        )
    }
  }
}
