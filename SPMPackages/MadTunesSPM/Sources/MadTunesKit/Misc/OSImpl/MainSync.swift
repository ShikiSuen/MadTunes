// This implementation is considered as copyleft from public domain.

import Foundation

@discardableResult
public func mainSync<T: Sendable>(execute work: @MainActor () throws -> T) rethrows -> T {
  if Thread.isMainThread {
    return try MainActor.assumeIsolated {
      try work()
    }
  }
  return try DispatchQueue.main.sync(execute: work)
}
