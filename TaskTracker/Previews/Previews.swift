//
//  Previews.swift
//  TaskTracker
//
//  Created by Chris Araman on 12/1/21.
//

import SwiftUI

struct AddTaskView_Previews: PreviewProvider {
  static var previews: some View {
    AddTaskView()
  }
}

struct TasksView_Previews: PreviewProvider {
  static var previews: some View {
    TasksView()
      .environmentObject(
        DatabaseViewModel(database: MockDatabaseService()))
  }
}

struct TaskRow_Previews: PreviewProvider {
  static var previews: some View {
    TaskRow(task: Task(name: "☑️ Some Task"))
  }
}
