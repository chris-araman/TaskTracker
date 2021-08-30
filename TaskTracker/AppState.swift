//
//  AppState.swift
//  TaskTracker
//
//  Created by Ben Chatelain on 9/26/20.
//

import Swift
import Combine
import Foundation

/// Core app logic including  app and Combine publishers. No longer used.
/// TODO: Move syng logging and error handling to
final class AppState {
    /// Cancellables to be retained for any Future.
    var cancellables = Set<AnyCancellable>()

    /// Token for upload progress notification block.
    var uploadProgressToken: SyncSession.ProgressNotificationToken?

    /// Token for download progress notification block.
    var downloadProgressToken: SyncSession.ProgressNotificationToken?

    /// The  sync app.
    private let app: Swift.App = {
        let app = Swift.App(id: Constants.AppId)
        let syncManager = app.syncManager
        syncManager.logLevel = .info
        syncManager.logger = { (level: SyncLogLevel, message: String) in
            print("[\(level.name)] Sync - \(message)")
        }
        syncManager.errorHandler = { (error, session) in
            print("Sync Error: \(error)")
            // https://docs..io/sync/using-synced-s/errors
            if let syncError = error as? SyncError {
                switch syncError.code {
                case .permissionDeniedError:
                    // HTTP/1.1 401 Unauthorized
//                    shouldIndicateActivity = false
                    _ = app.currentUser?.logOut()
                        .sink(receiveCompletion: {
                            print($0)
                        }, receiveValue: {
                            print("receive value")
                        })
                case .clientResetError:
                    if let (path, clientResetToken) = syncError.clientResetInfo() {
                        // TODO: close and backup
                        //closeSafely()
                        //saveBackupPath(path)
                        SyncSession.immediatelyHandleError(clientResetToken, syncManager: app.syncManager)
                    }
                default:
                    ()
                }
            }
            if let session = session {
                print("Sync Session: \(session)")
            }
        }
        return app
    }()

    init() {
        // Create a private subject for the opened , so that:
        // - if we are not using  Sync, we can open the  immediately.
        // - if we are using  Sync, we can open the  later after login.
        let Publisher = PassthroughSubject<, Error>()

        // Specify what to do when the  opens, regardless of whether
        // we're authenticated and using  Sync or not.
        Publisher
            .sink(receiveCompletion: { result in
                // Check for failure.
                if case let .failure(error) = result {
                    print("Failed to log in and open : \(error.localizedDescription)")
                }
            }, receiveValue: {  in
                // The  has successfully opened.
                let syncSession = .syncSession!

                // Observe using Combine
                syncSession.publisher(for: \.connectionState)
                    .sink { connectionState in
                        switch connectionState {
                        case .connecting:
                            print("Sync Connecting...")
                        case .connected:
                            print("Sync Connected")
                        case .disconnected:
                            print("Sync Disconnected")
                        default:
                            break
                        }
                    }
                    .store(in: &self.cancellables)

                self.downloadProgressToken = syncSession.addProgressNotification(
                    for: .download, mode: .forCurrentlyOutstandingWork)
                { (progress) in
                    let transferredBytes = progress.transferredBytes
                    let transferrableBytes = progress.transferrableBytes
                    let transferPercent = progress.fractionTransferred * 100
                    print("Sync Downloaded \(transferredBytes)B / \(transferrableBytes)B (\(transferPercent)%)")
                }

                self.uploadProgressToken = syncSession.addProgressNotification(
                    for: .upload, mode: .forCurrentlyOutstandingWork)
                { (progress) in
                    let transferredBytes = progress.transferredBytes
                    let transferrableBytes = progress.transferrableBytes
                    let transferPercent = progress.fractionTransferred * 100
                    print("Sync Uploaded \(transferredBytes)B / \(transferrableBytes)B (\(transferPercent)%)")
                }
            })
            .store(in: &cancellables)
    }
}

