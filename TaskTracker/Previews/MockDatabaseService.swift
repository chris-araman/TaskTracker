//
//  MockDatabase.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 8/9/21.
//

import CloudKit

class MockDatabaseService: DatabaseService {
  func accountStatus() async throws -> CKAccountStatus {
    .available
  }

  func fetchAll() async throws -> [Task] {
    [Task(name: "Foo"), Task(name: "Bar")]
  }

  func save(_ task: Task) async throws {
  }

  func delete(_ tasks: [Task.ID]) async throws {
  }
}
