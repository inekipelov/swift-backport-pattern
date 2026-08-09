#if canImport(ObjectiveC)
import Foundation

/// Namespace access for Objective-C runtime objects.
///
/// This extension only wraps `NSObjectProtocol` values in `Backport`. Consumer
/// modules define and own any concrete compatibility behavior added through
/// constrained `Backport` extensions.
public extension NSObjectProtocol {
    /// Exposes the receiver through the `Backport` namespace.
    ///
    /// This computed property wraps the NSObject instance in a `Backport` struct,
    /// giving consumer modules a constrained extension point without adding
    /// concrete compatibility behavior to this package.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let object = NSObject()
    /// let wrappedObject = object.backport
    /// ```
    ///
    /// - Returns: A namespace wrapper around this Objective-C object.
    var backport: Backport<Self> { .init(self) }
}

#endif
