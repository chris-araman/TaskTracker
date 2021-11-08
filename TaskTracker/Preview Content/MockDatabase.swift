//
//  MockDatabase.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 8/9/21.
//

import CombineCloudKit

class MockDatabase: Database {
    // static let preview = CombineCloudKitTests.MockDatabase()
    // _ = Task(name: "New task")
    // _ = Task(name: "Another task")
    func save(_ task: Task) async throws {
    }
}
