//
//  MockDatabase.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 8/9/21.
//

import CloudKit

actor MockDatabaseService: DatabaseService {
  var tasks: [Task.ID: Task] {
    let task = Task(name: "Foo")
    return [task.id: task]
  }

  func ready() async -> Bool {
    true
  }

  func fetchAll() async {
  }

  func save(_ task: Task) async throws {
  }

  func delete(_ tasks: [Task.ID]) async throws {
  }

  func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async throws -> Bool {
    true
  }
}
