//
//  AppDelegate.swift
//  TaskTracker
//
//  Created by Chris Araman on 12/8/21.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
  let database = CloudKitDatabaseService()

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    application.registerForRemoteNotifications()
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    precondition(application.isRegisteredForRemoteNotifications)
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    debugPrint(error)
    preconditionFailure()
  }

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
