//
//  AddTaskView.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/16/20.
//

import CombineCloudKit
import Combine
import SwiftUI

struct AddTaskView: View {
    @Environment(\.database) var database: Database
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @State private var enteredText: String = ""

    private var cancellable: AnyCancellable?

    var body: some View {
        Form {
            TextField("Task Name", text: $enteredText)
            Button("Save", action: add)
        }
        .navigationBarTitle("Add Task")
    }

    func add() {
        guard enteredText != "" else {
            print("Empty task, ignoring")
            return
        }

        _Concurrency.Task.detached {
            // Create a new Task with the text that the user entered.
            let task = Task(name: enteredText).record
            do {
                try await database.save(task)
                DispatchQueue.main.async {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                // TODO: Handle failure
                print("Failed: \(error)")
            }
        }
    }
}

struct AddTaskView_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskView()
    }
}
