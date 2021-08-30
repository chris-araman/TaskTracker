//
//  Constants.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 10/24/20.
//

import Foundation

struct Constants {
    static let appVersion: String = {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            else { fatalError("Info.plist does not contain CFBundleShortVersionString") }
        return version
    }()

    static let AppId: String = {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "_APP_ID") as? String
            else { fatalError("Info.plist does not contain _APP_ID") }
        return version
    }()

    /// FIXME: Temporary workaround to not being able to set the partitionValue for @AsyncOpen using the environment.
    static let testuserId: String = "60ac4fab713d3980e99a61d0"
}
