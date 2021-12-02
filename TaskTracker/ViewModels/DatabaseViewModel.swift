//
//  Database.swift
//  TaskTracker
//
//  Created by Chris Araman on 8/31/21.
//

import CloudKit
import SwiftUI

@MainActor
class DatabaseViewModel: ObservableObject {
  @Published var accountStatus = CKAccountStatus.couldNotDetermine
  @Published var tasks = [Task]()

  // TODO: Display this
  @Published var error: Error?

  private let database: DatabaseService
  private var map = [Task.ID: Task]()

  init(database: DatabaseService = CloudKitDatabaseService()) {
    self.database = database
    _Concurrency.Task.detached {
      await self.refresh()
    }
  }

  func refresh() async {
    self.error = nil
    do {
      self.accountStatus = try await self.database.accountStatus()
      self.map = try await self.database.fetchAll().reduce(into: [Task.ID: Task]()) { map, task in
        map[task.id] = task
      }
      self.tasks = map.values.sorted()
    } catch {
      self.error = error
    }
  }

  func save(_ task: Task) {
    _Concurrency.Task.detached {
      await self.save(task)
    }
  }

  private func update(_ tasks: [Task]) {
    for task in tasks {
      map.updateValue(task, forKey: task.id)
    }

    self.tasks = map.values.sorted()
  }

  private func remove(_ tasks: [Task]) {
    for task in tasks {
      map.removeValue(forKey: task.id)
    }

    self.tasks = map.values.sorted()
  }

  func save(_ task: Task) async {
    error = nil
    update([task])

    do {
      try await database.save(task.record)
    } catch {
      self.error = error
      remove([task])
    }
  }

  func delete(_ tasks: [Task]) {
    _Concurrency.Task.detached {
      await self.delete(tasks)
    }
  }

  func delete(_ tasks: [Task]) async {
    error = nil
    remove(tasks)

    do {
      try await database.delete(tasks.map(\.record.recordID))
    } catch {
      self.error = error
      update(tasks)
    }
  }
}
