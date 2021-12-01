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

@MainActor
class DatabaseViewModel: ObservableObject {
    @Published var accountStatus = CKAccountStatus.couldNotDetermine
    @Published var tasks = [Task]()

    // TODO: Display this
    @Published var error: Error?

    private let database: DatabaseService

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
            self.tasks = try await self.database.fetchAll()
        }
        catch {
            self.error = error
        }
    }

    func save(_ task: Task) {
        _Concurrency.Task.detached {
            await self.save(task)
        }
    }

    func save(_ task: Task) async {
        self.error = nil
        self.tasks.append(task)
        do {
            try await self.database.save(task.record)
        }
        catch {
            self.error = error
        }
    }

    func delete(_ tasks: [Task]) {
        _Concurrency.Task.detached {
            await self.delete(tasks)
        }
    }

    func delete(_ tasks: [Task]) async {
        self.error = nil
        self.tasks.removeAll { record in tasks.contains(record) }
        do {
            try await self.database.delete(tasks.map(\.record.recordID))
        }
        catch {
            self.error = error
        }
    }
}
