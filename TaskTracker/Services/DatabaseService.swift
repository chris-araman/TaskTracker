//
//  Database.swift
//  TaskTracker
//
//  Created by Chris Araman on 11/30/21.
//

import CloudKit
import Combine
import CombineCloudKit

protocol DatabaseService: Actor {
  var tasks: [Task.ID: Task] { get }

  func ready() async -> Bool
  func fetchAll() async throws
  func save(_ task: Task) async throws
  func delete(_ tasks: [Task.ID]) async throws
  func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async throws -> Bool
}

actor CloudKitDatabaseService: DatabaseService {
  private let container = CKContainer.default()
  private let database: CKDatabase
  private var zone = CKRecordZone(zoneName: "Tasks")
  private let subscriptionID = "task-changes"
  private var changeToken: CKServerChangeToken?
  var tasks = [Task.ID: Task]()

  init() {
    database = container.privateCloudDatabase
  }

  func ready() async -> Bool {
    guard await accountStatus() == .available else {
      return false
    }

    do {
      try await ensureRecordZone()
      try await ensureSubscription()
      try await fetchAll()
    } catch {
      return false
    }

    return true
  }

  func fetch() async -> [Task.ID: Task] {
    tasks
  }

  private func accountStatus() async -> CKAccountStatus {
    await withCancellableContinuation { continuation in
      container
        .accountStatus()
        .catch { _ in
          Just(.couldNotDetermine)
        }
        .sink { status in
          continuation.resume(returning: status)
        }
    }
  }

  private func ensureRecordZone() async throws {
    do {
      zone = try await fetchRecordZone()
    } catch {
      zone = try await saveRecordZone()
    }

    precondition(zone.capabilities.contains(.fetchChanges))
  }

  private func fetchRecordZone() async throws -> CKRecordZone {
    return try await withCancellableThrowingContinuation { continuation in
      database
        .fetch(recordZoneID: zone.zoneID)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
            }
          },
          receiveValue: { zone in
            continuation.resume(returning: zone)
          }
        )
    }
  }

  private func saveRecordZone() async throws -> CKRecordZone {
    return try await withCancellableThrowingContinuation { continuation in
      database
        .save(recordZone: zone)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
            }
          },
          receiveValue: { zone in
            continuation.resume(returning: zone)
          }
        )
    }
  }

  private func ensureSubscription() async throws {
    do {
      try await fetchSubscription()
    } catch {
      try await saveSubscription()
    }
  }

  private func fetchSubscription() async throws {
    try await withCancellableThrowingContinuation { continuation in
      database
        .fetch(subscriptionID: subscriptionID)
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

  private func saveSubscription() async throws {
    let subscription = CKRecordZoneSubscription(zoneID: zone.zoneID, subscriptionID: subscriptionID)
    subscription.recordType = "Task"
    subscription.notificationInfo = CKSubscription.NotificationInfo(
      shouldSendContentAvailable: true)
    try await withCancellableThrowingContinuation { continuation in
      database
        .save(subscription: subscription)
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

  func fetchAll() async throws {
    try await withCancellableThrowingContinuation { continuation in
      database.performQuery(ofType: "Task")
        .map { record in
          Task(from: record)
        }
        .collect()
        .map { tasks -> [Task.ID: Task] in
          var map = [Task.ID: Task]()
          for task in tasks {
            map[task.id] = task
          }

          return map
        }
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
            }
          },
          receiveValue: { tasks in
            self.tasks = tasks
            continuation.resume()
          }
        )
    }
  }

  func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async throws -> Bool {
    guard
      let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        as? CKRecordZoneNotification,
      notification.subscriptionID == subscriptionID,
      notification.databaseScope == .private,
      notification.recordZoneID == zone.zoneID
    else {
      return false
    }

    let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
    config.previousServerChangeToken = changeToken
    let operation = CKFetchRecordZoneChangesOperation(
      recordZoneIDs: [zone.zoneID],
      configurationsByRecordZoneID: [zone.zoneID: config])
    operation.recordWasChangedBlock = { recordID, result in
      guard case .success(let record) = result else {
        return
      }

      self.tasks.updateValue(Task(from: record), forKey: recordID)
    }
    operation.recordWithIDWasDeletedBlock = { recordID, _ in
      self.tasks.removeValue(forKey: recordID)
    }
    operation.recordZoneChangeTokensUpdatedBlock = { recordZoneID, token, _ in
      precondition(recordZoneID == self.zone.zoneID)
      self.changeToken = token
    }
    operation.recordZoneFetchResultBlock = { recordZoneID, result in
      guard case .success(let (token, _, _)) = result else {
        return
      }

      precondition(recordZoneID == self.zone.zoneID)
      self.changeToken = token
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      operation.fetchRecordZoneChangesResultBlock = { result in
        if case .failure(let error) = result {
          continuation.resume(throwing: error)
          return
        }

        continuation.resume()
      }

      database.add(operation)
    }

    return true
  }

  func save(_ task: Task) async throws {
    // TODO: Store round-tripped recordID with zone.zoneID
    try await withCancellableThrowingContinuation { continuation in
      database
        .save(record: task.record)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
              return
            }

            continuation.resume()
          },
          receiveValue: { record in
            self.tasks.updateValue(Task(from: record), forKey: record.recordID)
          }
        )
    }
  }

  func delete(_ tasks: [Task.ID]) async throws {
    try await withCancellableThrowingContinuation { continuation in
      database
        .delete(recordIDs: tasks)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
              return
            }

            continuation.resume()
          },
          receiveValue: { recordID in
            self.tasks.removeValue(forKey: recordID)
          }
        )
    }
  }
}
