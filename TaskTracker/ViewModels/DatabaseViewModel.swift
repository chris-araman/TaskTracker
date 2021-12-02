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
    self.accountStatus = await self.database.accountStatus()
    do {
      self.map = try await self.database.fetchAll().reduce(into: [Task.ID: Task]()) { map, task in
        map[task.id] = task
      }
      publish()
    } catch {
      self.error = error
    }
  }

  func save(_ task: Task) {
    _Concurrency.Task.detached {
      await self.save(task)
    }
  }

  func save(_ task: Task) async {
    error = nil
    update([task])

    do {
      try await database.save(task)
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
      try await database.delete(tasks.map(\.id))
    } catch {
      self.error = error
      update(tasks)
    }
  }

  private func update(_ tasks: [Task]) {
    for task in tasks {
      map.updateValue(task, forKey: task.id)
    }

    publish()
  }

  private func remove(_ tasks: [Task]) {
    for task in tasks {
      map.removeValue(forKey: task.id)
    }

    publish()
  }

  private func publish() {
    withAnimation {
      self.tasks = map.values.sorted()
    }
  }
}
