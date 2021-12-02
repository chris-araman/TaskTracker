//
//  Concurrency.swift
//  TaskTracker
//
//  Created by Chris Araman on 12/2/21.
//

import Combine

func withCancellableContinuation<T>(
  _ foo: (CheckedContinuation<T, Never>) -> AnyCancellable
) async -> T {
  var cancellable: AnyCancellable?
  let value = await withCheckedContinuation { continuation in
    cancellable = foo(continuation)
  }
  withExtendedLifetime(cancellable) {}
  return value
}

func withCancellableContinuation(
  _ foo: (CheckedContinuation<Void, Never>) -> AnyCancellable
) async {
  var cancellable: AnyCancellable?
  await withCheckedContinuation { continuation in
    cancellable = foo(continuation)
  }
  withExtendedLifetime(cancellable) {}
}

func withCancellableThrowingContinuation<T>(
  _ foo: (CheckedContinuation<T, Error>) -> AnyCancellable
) async throws -> T {
  var cancellable: AnyCancellable?
  let value = try await withCheckedThrowingContinuation { continuation in
    cancellable = foo(continuation)
  }
  withExtendedLifetime(cancellable) {}
  return value
}

func withCancellableThrowingContinuation(
  _ foo: (CheckedContinuation<Void, Error>) -> AnyCancellable
) async throws {
  var cancellable: AnyCancellable?
  try await withCheckedThrowingContinuation { continuation in
    cancellable = foo(continuation)
  }
  withExtendedLifetime(cancellable) {}
}
