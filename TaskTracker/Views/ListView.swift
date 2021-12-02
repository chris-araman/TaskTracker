//
//  ListView.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/15/20.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var database: DatabaseViewModel

    var body: some View {
        List() {
            ForEach(database.tasks) { task in
                TaskRow(task: task)
            }
            .onDelete { indices in
                let toDelete = indices.map { index in
                    database.tasks[index]
                }
                database.delete(toDelete)
            }
        }
        .refreshable {
            await database.refresh()
        }
        .navigationBarTitle("Tasks")
        .toolbar {
            NavigationLink(destination: AddTaskView()) {
                Image(systemName: "plus")
            }
        }
    }
}

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        ListView()
            .navigationBarTitle("Tasks")
            .environmentObject(
                DatabaseViewModel(database: MockDatabaseService()))
    }
}
