#if canImport(SwiftUI)
import SwiftUI

/// Extensions for SwiftUI views to support backport functionality.
///
/// This extension adds backport support to all SwiftUI `View` instances, enabling
/// the use of modern SwiftUI features on older iOS, macOS, watchOS, and tvOS versions.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension View {
    /// A view modifier that provides backport functionality for SwiftUI views.
    ///
    /// This computed property wraps the view in a `Backport` struct, enabling the
    /// addition of modern SwiftUI features through backport extensions. This is
    /// particularly useful when you want to use newer SwiftUI APIs while maintaining
    /// compatibility with older OS versions.
    ///
    /// ## Overview
    ///
    /// The backport system allows you to use modern SwiftUI features in apps that
    /// need to support older OS versions. By using the backport property, you can
    /// access implementations of newer APIs that have been adapted to work on
    /// older versions of SwiftUI.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// Text("Hello, World!")
    ///     .backport.someModernFeature()
    /// ```
    ///
    /// - Returns: A `Backport` wrapper around this view that provides access
    ///   to backported SwiftUI functionality.
    ///
    /// - Note: This modifier is available only when SwiftUI can be imported,
    ///   ensuring compatibility across different platform targets.
    var backport: Backport<Self> { .init(self) }
}

#endif