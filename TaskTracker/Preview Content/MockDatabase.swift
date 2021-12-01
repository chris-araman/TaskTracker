//
//  MockDatabase.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 8/9/21.
//

import CloudKit
import CombineCloudKit

class MockDatabase: Database {
    var accountStatus: CKAccountStatus {
        get { .available }
    }

    var tasks: [Task] {
        get { [Task(name: "Foo"), Task(name: "Bar")] }
    }

    func save(_ task: CKRecord) async throws {
    }

    func delete(_ tasks: [CKRecord.ID]) async throws {
    }
}
