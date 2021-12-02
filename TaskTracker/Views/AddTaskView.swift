//
//  AddTaskView.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/16/20.
//

import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var database: DatabaseViewModel
    @Environment(\.dismiss) var dismiss: DismissAction

    @State private var enteredText: String = ""

    var body: some View {
        Form {
            TextField("Task Name", text: $enteredText)
            Button("Save", action: add)
                .disabled(enteredText.isEmpty)
        }
        .navigationBarTitle("Add Task")
    }

    func add() {
        // Create a new Task with the text that the user entered.
        let task = Task(name: enteredText)

        // FIXME: Assumes success.
        database.save(task)
        dismiss()
    }
}

struct AddTaskView_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskView()
    }
}
