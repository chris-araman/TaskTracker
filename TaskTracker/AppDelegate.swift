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
