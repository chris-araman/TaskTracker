//
//  TaskRow.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/16/20.
//

import SwiftUI

struct TaskRow: View {
  @EnvironmentObject var database: DatabaseViewModel
  @Binding var task: Task

  var body: some View {
    HStack {
      Text(task.name)

      Spacer()

      switch task.status {
      case .Open:
        EmptyView()
      case .InProgress:
        Text("In Progress")
      case .Complete:
        Text("✅")
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      cycleTaskStatus()
    }
  }

  func cycleTaskStatus() {
    switch task.status {
    case .Open:
      task.status = .InProgress
    case .InProgress:
      task.status = .Complete
    case .Complete:
      task.status = .Open
    }

    database.save(task)
  }
}
