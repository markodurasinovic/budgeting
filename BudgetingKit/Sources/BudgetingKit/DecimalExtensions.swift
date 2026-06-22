import Foundation
import SwiftUI

/// Conversions from `Decimal` to the numeric types SwiftUI and AppKit expect.
///
/// SwiftUI's `CGFloat` and `String(format:)` don't accept `Decimal` directly, so
/// call sites used to repeat `NSDecimalNumber(decimal: x).doubleValue` and
/// `CGFloat(truncating: NSDecimalNumber(decimal: x))` inline. These helpers give
/// that boilerplate a single, readable home.
public extension Decimal {
    /// A `Double` suitable for `String(format:)` and `UserDefaults.set(_:forKey:)`.
    /// Uses `NSDecimalNumber` under the hood for a faithful conversion.
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    /// A `CGFloat` suitable for SwiftUI frame/width math. Truncates rather than
    /// rounding so a 0.9999 ratio doesn't accidentally round up to 1.0.
    var cgFloatValue: CGFloat {
        CGFloat(truncating: NSDecimalNumber(decimal: self))
    }
}
