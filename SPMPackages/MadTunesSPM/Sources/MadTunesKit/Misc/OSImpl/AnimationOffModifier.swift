// This implementation is considered as copyleft from public domain.

import SwiftUI

extension Animation {
  public func nerf(_ condition: Bool? = nil) -> Animation? {
    (condition ?? true) ? .nerfed : self
  }

  public static var nerfed: Animation {
    .easeOut(duration: 0.1)
  }
}
