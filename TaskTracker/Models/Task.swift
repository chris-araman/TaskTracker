//
//  Task.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/26/20.
//

import CloudKit

struct Task: Hashable, Identifiable {
    enum Status: String {
        case Open
        case InProgress
        case Complete
    }

    let record: CKRecord

    init() {
        self.init(from: CKRecord(recordType: "Task"))
    }

    /// Initializer for previews.
    init(name: String) {
        self.init()
        self.name = name
    }

    init(from record: CKRecord) {
        self.record = record
    }

    /// The stable identity of the entity associated with this instance.
    var id: CKRecord.ID {
        get { record.recordID }
    }

    /// Displayed name of the task.
    var name: String {
        get {
            guard let value = record["name"] as? String else {
                return "Unknown"
            }

            return value
        }

        set {
            record["name"] = newValue
        }
    }

    /// Current status of the task. Defaults to "Open".
    var status: Status {
        get {
            guard let value = record["status"] as? String,
                let status = Status(rawValue: value) else {
                return .Open
            }

            return status
        }

        set {
            record["status"] = newValue.rawValue
        }
    }
}
