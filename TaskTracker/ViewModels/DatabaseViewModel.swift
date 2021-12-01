//
//  Database.swift
//  TaskTracker
//
//  Created by Chris Araman on 8/31/21.
//

import CloudKit
import SwiftUI

extension View {
    func database(_ database: DatabaseViewModel) -> some View {
        environmentObject(database)
    }
}

class DatabaseViewModel: ObservableObject {
    @Published var accountStatus = CKAccountStatus.couldNotDetermine
    @Published var tasks = [Task]()

    private let database: DatabaseService

    init(database: DatabaseService = CloudKitDatabaseService()) {
        self.database = database
        refresh()
    }

    func refresh() {
        _Concurrency.Task.detached {
            do {
                self.accountStatus = try await self.database.accountStatus()
                self.tasks = try await self.database.fetchAll()
            }
            catch {
                // TODO: Handle failure
                print("Failed: \(error)")
            }
        }
    }

    func save(_ task: Task) {
        _Concurrency.Task.detached {
            do {
                try await self.database.save(task.record)
            }
            catch {
                // TODO: Handle failure
                print("Failed: \(error)")
            }
        }
    }

    func delete(_ tasks: [Task]) {
        _Concurrency.Task.detached {
            do {
                try await self.database.delete(tasks.map(\.record.recordID))
            }
            catch {
                // TODO: Handle failure
                print("Failed: \(error)")
            }
        }
    }
}
