// This implementation is considered as copyleft from public domain.

import Foundation

// MARK: - Debouncer

public actor Debouncer {
  // MARK: Lifecycle

  public init(delay: TimeInterval) {
    self.delay = delay
  }

  // MARK: Public

  public func debounce(
    keepFirstAttemptInstead: Bool = false,
    _ action: @Sendable @escaping () async -> Void
  ) async {
    if keepFirstAttemptInstead {
      guard !isInExclusiveState else { return }
    }
    task?.cancel()
    task = Task { @MainActor [weak self] in
      guard let self else { return }
      await setExclusiveState(true)
      if keepFirstAttemptInstead {
        await action()
      }
      try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      await setExclusiveState(false)
      try Task.checkCancellation()
      if !keepFirstAttemptInstead {
        await action()
      }
    }
  }

  nonisolated public func debounceOnMain(
    keepFirstAttemptInstead: Bool = false,
    _ action: @MainActor @escaping () async -> Void
  ) {
    Task {
      await debounce(keepFirstAttemptInstead: keepFirstAttemptInstead) {
        await action()
      }
    }
  }

  // MARK: Private

  private var task: Task<Void, Error>?
  private var isInExclusiveState: Bool = false
  private let delay: TimeInterval

  private func setExclusiveState(_ newValue: Bool) {
    isInExclusiveState = newValue
  }
}
