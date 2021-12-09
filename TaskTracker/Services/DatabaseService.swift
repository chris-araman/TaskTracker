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
  // TODO: Persist whether zone has been created.
  static let zoneID = CKRecordZone.ID(zoneName: "Tasks")

  // TODO: Persist local cache atomically with changeToken.
  // TODO: Notify DatabaseViewModel when this changes.
  var tasks = [Task.ID: Task]()

  private let container = CKContainer.default()
  private let database: CKDatabase

  // TODO: Persist whether subscription has been created.
  private let subscriptionID = "task-changes"
  private var changeToken: CKServerChangeToken?

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
    let zone = try await withCancellableThrowingContinuation { continuation in
      database
        .fetch(recordZoneID: CloudKitDatabaseService.zoneID)
        .catch { error -> AnyPublisher<CKRecordZone, Error> in
          // If a zone could not be fetched, save one.
          guard let error = error as? CKError,
            let partial = error.partialErrorsByItemID?[CloudKitDatabaseService.zoneID] as? CKError,
            partial.code == .unknownItem
          else {
            return Fail(error: error).eraseToAnyPublisher()
          }

          let zone = CKRecordZone(zoneID: CloudKitDatabaseService.zoneID)
          return self.database.save(recordZone: zone)
        }
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              debugPrint(error)
              continuation.resume(throwing: error)
            }
          },
          receiveValue: { zone in
            continuation.resume(returning: zone)
          }
        )
    }

    precondition(zone.capabilities.contains(.fetchChanges))
    precondition(CloudKitDatabaseService.zoneID == zone.zoneID)
  }

  private func ensureSubscription() async throws {
    try await withCancellableThrowingContinuation { continuation in
      database
        .fetch(subscriptionID: subscriptionID)
        .catch { error -> AnyPublisher<CKSubscription, Error> in
          // If a subscription could not be fetched, save one.
          guard let error = error as? CKError,
            let partial = error.partialErrorsByItemID?[self.subscriptionID] as? CKError,
            partial.code == .unknownItem
          else {
            return Fail(error: error).eraseToAnyPublisher()
          }

          let subscription = CKRecordZoneSubscription(
            zoneID: CloudKitDatabaseService.zoneID, subscriptionID: self.subscriptionID)
          subscription.recordType = "Task"
          subscription.notificationInfo =
            CKSubscription.NotificationInfo(shouldSendContentAvailable: true)
          return self.database.save(subscription: subscription).eraseToAnyPublisher()
        }
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              debugPrint(error)
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
              debugPrint(error)
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
      notification.recordZoneID?.zoneName == CloudKitDatabaseService.zoneID.zoneName
    else {
      return false
    }

    let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
    config.previousServerChangeToken = changeToken
    let operation = CKFetchRecordZoneChangesOperation(
      recordZoneIDs: [CloudKitDatabaseService.zoneID],
      configurationsByRecordZoneID: [CloudKitDatabaseService.zoneID: config])
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
      precondition(recordZoneID == CloudKitDatabaseService.zoneID)
      self.changeToken = token
    }
    operation.recordZoneFetchResultBlock = { recordZoneID, result in
      guard case .success(let (token, _, _)) = result else {
        return
      }

      precondition(recordZoneID == CloudKitDatabaseService.zoneID)
      self.changeToken = token
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      operation.fetchRecordZoneChangesResultBlock = { result in
        if case .failure(let error) = result {
          debugPrint(error)
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
    try await withCancellableThrowingContinuation { continuation in
      database
        .save(record: task.record)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              debugPrint(error)
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
              debugPrint(error)
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
