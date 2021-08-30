//
//  MockDatabase.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 8/9/21.
//

class MockDatabase {
    static var previewRealm: Realm {
        get {
            let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "previewRealm", objectTypes: [Task.self]))
            try! realm.write {
                _ = Task(name: "New task")
                _ = Task(name: "Another task")
            }
            return realm
        }
    }
}
