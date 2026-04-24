#if canImport(ObjectiveC)
import Foundation

/// Extensions for Objective-C runtime objects to support backport functionality.
///
/// This extension adds backport support to all `NSObject` instances, enabling
/// the use of modern API features on older framework versions for Objective-C
/// based objects.
public extension NSObjectProtocol {
    /// Provides backport functionality for NSObject instances.
    ///
    /// This computed property wraps the NSObject instance in a `Backport` struct,
    /// enabling the addition of modern API features through backport extensions.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let label = UILabel()
    /// let backportedLabel = label.backport
    /// ```
    ///
    /// - Returns: A `Backport` wrapper around this NSObject instance.
    var backport: Backport<Self> { .init(self) }
}

#endif
