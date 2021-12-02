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
  func accountStatus() async throws -> CKAccountStatus
  func fetchAll() async throws -> [Task]
  func save(_ task: Task) async throws
  func delete(_ tasks: [Task.ID]) async throws
}

class CloudKitDatabaseService: DatabaseService {
  private let container = CKContainer.default()

  // TODO: Does this grow indefinitely?
  private var cancellables = Set<AnyCancellable>()

  private var database: CCKDatabase {
    container.privateCloudDatabase
  }

  func accountStatus() async throws -> CKAccountStatus {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<CKAccountStatus, Error>) in
      container.accountStatus()
        .catch { _ in
          Just(.couldNotDetermine)
        }
        .sink { status in
          continuation.resume(returning: status)
        }
        .store(in: &cancellables)
    }
  }

  func fetchAll() async throws -> [Task] {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<[Task], Error>) in
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
        .store(in: &cancellables)
    }
  }

  func save(_ task: Task) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
        .store(in: &cancellables)
    }
  }

  func delete(_ tasks: [Task.ID]) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
        .store(in: &cancellables)
    }
  }
}
