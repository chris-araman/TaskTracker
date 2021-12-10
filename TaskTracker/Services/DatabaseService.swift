//
//  Database.swift
//  TaskTracker
//
//  Created by Chris Araman on 11/30/21.
//

import CloudKit
import Combine
import CombineCloudKit

@MainActor
protocol DatabaseService {
  var tasks: AnyPublisher<[Task], Never> { get }

  func ready() async -> Bool
  func fetchAll() async throws
  func save(_ task: Task) async throws
  func delete(_ tasks: [Task.ID]) async throws
  func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async throws -> Bool
}

class CloudKitDatabaseService: DatabaseService {
  static let zoneID = CKRecordZone.ID(zoneName: "Tasks")

  private let container = CKContainer.default()
  private let database: CKDatabase
  private let subscriptionID = "task-changes"

  // TODO: Persist local cache atomically with changeToken.
  private var subject = CurrentValueSubject<[Task.ID: Task], Never>([:])
  private var changeToken: CKServerChangeToken?

  init() {
    self.database = container.privateCloudDatabase
  }

  var tasks: AnyPublisher<[Task], Never> {
    subject.map { tasks in
      tasks.values.sorted()
    }.eraseToAnyPublisher()
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
    try await withCancellableThrowingContinuation { continuation in
      database
        .save(recordZone: CKRecordZone(zoneID: CloudKitDatabaseService.zoneID))
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              debugPrint(error)
              continuation.resume(throwing: error)
              return
            }

            continuation.resume()
          },
          receiveValue: { zone in
            precondition(zone.capabilities.contains(.fetchChanges))
            precondition(CloudKitDatabaseService.zoneID == zone.zoneID)
          }
        )
    }
  }

  private func ensureSubscription() async throws {
    let subscription = CKRecordZoneSubscription(
      zoneID: CloudKitDatabaseService.zoneID, subscriptionID: subscriptionID)
    subscription.recordType = "Task"
    subscription.notificationInfo =
      CKSubscription.NotificationInfo(shouldSendContentAvailable: true)
    try await withCancellableThrowingContinuation { continuation in
      database.save(subscription: subscription)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              debugPrint(error)
              continuation.resume(throwing: error)
              return
            }

            continuation.resume()
          },
          receiveValue: { subscription in
            precondition(subscription.subscriptionID == self.subscriptionID)
          }
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
        .receive(on: DispatchQueue.main)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              debugPrint(error)
              continuation.resume(throwing: error)
            }
          },
          receiveValue: { tasks in
            self.subject.value = tasks
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

    // Fetch changes from iCloud.
    var tasksToUpdate = [Task.ID: Task]()
    var tasksToRemove = Set<Task.ID>()
    var newChangeToken: CKServerChangeToken?
    let operation = CKFetchRecordZoneChangesOperation(
      recordZoneIDs: [CloudKitDatabaseService.zoneID],
      configurationsByRecordZoneID: [
        CloudKitDatabaseService.zoneID: .init(previousServerChangeToken: changeToken)
      ])
    operation.recordWasChangedBlock = { recordID, result in
      guard case .success(let record) = result else {
        return
      }

      tasksToUpdate.updateValue(Task(from: record), forKey: recordID)
      tasksToRemove.remove(recordID)
    }
    operation.recordWithIDWasDeletedBlock = { recordID, _ in
      tasksToUpdate.removeValue(forKey: recordID)
      tasksToRemove.insert(recordID)
    }
    operation.recordZoneChangeTokensUpdatedBlock = { recordZoneID, token, _ in
      precondition(recordZoneID == CloudKitDatabaseService.zoneID)
      newChangeToken = token
    }
    operation.recordZoneFetchResultBlock = { recordZoneID, result in
      guard case .success(let (token, _, _)) = result else {
        return
      }

      precondition(recordZoneID == CloudKitDatabaseService.zoneID)
      newChangeToken = token
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

    precondition(Set(tasksToUpdate.keys).isDisjoint(with: tasksToRemove))

    // Apply changes to local state.
    for task in tasksToRemove {
      subject.value.removeValue(forKey: task)
    }

    subject.value.merge(tasksToUpdate) { (old, new) in new }

    changeToken = newChangeToken

    return true
  }

  func save(_ task: Task) async throws {
    var tasksRemaining = self.update([task])
    try await withCancellableThrowingContinuation { continuation in
      database
        .save(record: task.record)
        .receive(on: DispatchQueue.main)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              debugPrint(error)

              if tasksRemaining.isEmpty {
                // Remove any tasks that were not successfully added.
                self.remove([task.id])
              } else {
                // Restore any tasks that were not successfully updated.
                self.update(tasksRemaining)
              }

              continuation.resume(throwing: error)
              return
            }

            precondition(tasksRemaining.isEmpty)
            continuation.resume()
          },
          receiveValue: { record in
            tasksRemaining.removeAll { task in
              task.id == record.recordID
            }
          }
        )
    }
  }

  func delete(_ taskIDs: [Task.ID]) async throws {
    var tasksRemaining = self.remove(taskIDs)
    try await withCancellableThrowingContinuation { continuation in
      database
        .delete(recordIDs: taskIDs)
        .receive(on: DispatchQueue.main)
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              debugPrint(error)

              // Restore any tasks that were not successfully deleted.
              self.update(tasksRemaining)

              continuation.resume(throwing: error)
              return
            }

            precondition(tasksRemaining.isEmpty)
            continuation.resume()
          },
          receiveValue: { recordID in
            tasksRemaining.removeAll { task in
              task.id == recordID
            }
          }
        )
    }
  }

  // Returns the tasks that were updated.
  @discardableResult private func update(_ tasks: [Task]) -> [Task] {
    tasks.compactMap { task in
      self.subject.value.updateValue(task, forKey: task.id)
    }
  }

  // Returns the tasks that were removed.
  @discardableResult private func remove(_ taskIDs: [Task.ID]) -> [Task] {
    taskIDs.compactMap { taskID in
      self.subject.value.removeValue(forKey: taskID)
    }
  }
}
