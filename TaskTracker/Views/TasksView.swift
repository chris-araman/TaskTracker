//
//  TasksView.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 8/9/21.
//

import SwiftUI

// MARK: Main View
/// View that presents the ListView once a user is logged in.
struct TasksView: View {

    var body: some View {
        VStack {
            switch asyncOpen {
            case .connecting:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            case .waitingForUser:
                ProgressView("Waiting for user to be logged in...")
            case .open(let realm):
                ListView(editTask: Task())
                    .environment(\.realm, realm)
            case .error(let error):
                ErrorView(error: error)
            case .progress(_):
                ProgressView()
            }
        }
    }
}
