//
//  TasksView.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 8/9/21.
//

import SwiftUI

struct TasksView: View {
  var body: some View {
    NavigationView {
      ListView()
    }
    .toolbar {
      ToolbarItem {
        NavigationLink("Add", destination: AddTaskView())
      }
    }
  }
}

struct TasksView_Previews: PreviewProvider {
  static var previews: some View {
    TasksView()
  }
}
