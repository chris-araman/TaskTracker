//
//  App.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/15/20.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
  let database = CloudKitDatabaseService()

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) async -> UIBackgroundFetchResult {
    do {
      guard try await database.didReceiveRemoteNotification(userInfo) else {
        return .noData
      }
    } catch {
      return .failed
    }

    return .newData
  }
}

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
