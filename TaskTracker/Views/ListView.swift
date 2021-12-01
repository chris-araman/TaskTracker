//
//  ListView.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/15/20.
//

import CombineCloudKit
import SwiftUI

/// Screen containing a list of tasks. Implements functionality for adding, rearranging, and deleting tasks.
struct ListView: View {
    @Environment(\.database) var database: Database
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    /// All of the user's tasks.
    private var tasks : [Task] {
        get { database.tasks }
    }
    // FIXME: database.fetch("Task").map(Task.init(from:))

    @State private var showingActionSheet = false

    /// Selected task for updating status.
    @State private var selection: Task.ID?
    //@StateObject var editTask: Task

    var body: some View {
        List(selection: $selection) {
            ForEach(tasks) { task in
                TaskRow(task: task)
                    .onTapGesture {
                        showingActionSheet = true
                    }
                    .actionSheet(isPresented: $showingActionSheet, content: editTaskStatus)
            }
            .onDelete { indices in
                let toDelete = indices.map { index in
                    tasks[index].record.recordID
                }
                _Concurrency.Task.detached {
                    do {
                        try await database.delete(toDelete)
                    } catch {
                        // TODO: Handle failure
                        print("Failed: \(error)")
                    }
                }
            }
//            .onMove(perform: tasks.move)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitle("Tasks", displayMode: .large)
        .navigationBarItems(
            trailing:
                withAnimation(.easeInOut(duration: 3.0)) {
                    NavigationLink(destination: AddTaskView()) {
                        Text("+")
                    }
                }
        )
    }

    var editTask: Task? {
        tasks.first { task in task.id == selection }
    }

    /// Builds an action sheet to toggle the selected task's status.
    func editTaskStatus() -> ActionSheet {
        var buttons: [Alert.Button] = []

        // If the task is not in the Open state, we can set it to open. Otherwise, that action will not be available.
        // We do this for the other two states -- InProgress and Complete.
        if (editTask?.status != .Open) {
            buttons.append(.default(Text("Open"), action: {
                self.setTaskStatus(newStatus: .Open)
            }))
        }

        if (editTask?.status != .InProgress) {
            buttons.append(.default(Text("Start Progress"), action: {
                self.setTaskStatus(newStatus: .InProgress)
            }))
        }

        if (editTask?.status != .Complete) {
            buttons.append(.default(Text("Complete"), action: {
                self.setTaskStatus(newStatus: .Complete)
            }))
        }

        buttons.append(.cancel())

        return ActionSheet(title: Text(editTask?.name ?? ""), message: Text("Select an action"), buttons: buttons)
    }

    /// Sets editTask to the given status. The task and its realm are fozen and must be thawed to change.
    /// - Parameter newStatus: TaskStatus to set
    func setTaskStatus(newStatus: Task.Status) {
        guard var editTask = editTask else {
            return
        }

        editTask.status = newStatus
        let record = editTask.record
        _Concurrency.Task.detached {
            do {
                try await database.save(record)
            } catch {
                // TODO: Handle failure
            }
        }
    }

}

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        ListView()
            .navigationBarTitle("Tasks")
            .database(MockDatabase())
    }
}
