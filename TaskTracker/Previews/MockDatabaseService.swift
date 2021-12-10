//
//  MockDatabase.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 8/9/21.
//

import CloudKit
import Combine

class MockDatabaseService: DatabaseService {
  var tasks: AnyPublisher<[Task], Never> {
    Just([Task(name: "Foo")]).eraseToAnyPublisher()
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
