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
    @State private var name: String = ""
    @FocusState var nameHasFocus: Bool

    var body: some View {
        Form {
            TextField("Task Name", text: $name)
                .focused($nameHasFocus)
            Button("Save", action: add)
                .disabled(name.isEmpty)
        }
        .navigationBarTitle("Add Task")
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                nameHasFocus = true
            }
        }
    }

    func add() {
        // FIXME: Assumes success.
        database.save(Task(name: name))
        dismiss()
    }
}

struct AddTaskView_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskView()
    }
}
