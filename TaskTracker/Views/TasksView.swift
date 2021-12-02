//
//  TasksView.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 8/9/21.
//

import SwiftUI

struct TasksView: View {
  @EnvironmentObject var database: DatabaseViewModel

  var body: some View {
    NavigationView {
      List {
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
}
