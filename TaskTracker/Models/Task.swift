//
//  Task.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/26/20.
//

import CloudKit

class Task: Identifiable, ObservableObject {
    enum Status: String {
        case Open
        case InProgress
        case Complete
    }

    let record: CKRecord

    /// Initializer for previews.
    convenience init(name: String) {
        self.init()
        self.name = name
    }

    convenience init() {
        self.init(from: CKRecord(recordType: "Task"))
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
        get { record["name"] as! String }
        set { record["name"] = newValue }
    }

    /// Current status of the task. Defaults to "Open".
    var status: Status {
        get { Status(rawValue: record["status"] as! String)! }
        set { record["status"] = newValue.rawValue }
    }
}
