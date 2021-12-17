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
  @Published var tasks = [Task]()

  #warning("TODO: Display the error.")
  @Published var error: Error?

  private let database: DatabaseService

  init(database: DatabaseService) {
    self.database = database
    self.database.tasks.assign(to: &$tasks)
    _Concurrency.Task.detached {
      await self.operate {
        let ready = await self.database.ready()
        if !ready {
          #warning("TODO: Assign self.error.")
        }
      }
    }
  }

  func refresh() async {
    await self.operate {
      try await self.database.fetchAll()
    }
  }

  func save(_ task: Task) {
    _Concurrency.Task.detached {
      await self.operate {
        try await self.database.save(task)
      }
    }
  }

  func delete(_ tasks: [Task]) {
    _Concurrency.Task.detached {
      await self.operate {
        try await self.database.delete(tasks.map(\.id))
      }
    }
  }

  private func operate(_ operation: () async throws -> Void) async {
    error = nil
    do {
      try await operation()
    } catch {
      self.error = error
      return
    }
  }
}
