//
//  App.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/15/20.
//

import SwiftUI

@main
struct App: SwiftUI.App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup {
      TasksView()
        .environmentObject(DatabaseViewModel(database: appDelegate.database))
    }
  }
}
