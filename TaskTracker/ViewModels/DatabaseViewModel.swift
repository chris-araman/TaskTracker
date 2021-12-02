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
    private var set = Set<Task>()

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
            self.set = Set(try await self.database.fetchAll())
            self.tasks = set.sorted()
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

    private func addOrUpdate(_ tasks: [Task]) {
        for task in tasks {
            set.insert(task)
        }

        withAnimation {
            self.tasks = set.sorted()
        }
    }

    private func remove(_ tasks: [Task]) {
        for task in tasks {
            set.remove(task)
        }

        withAnimation {
            self.tasks = set.sorted()
        }
    }

    func save(_ task: Task) async {
        error = nil
        addOrUpdate([task])

        do {
            try await database.save(task.record)
        }
        catch {
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
        }
        catch {
            self.error = error
            addOrUpdate(tasks)
        }
    }
}
