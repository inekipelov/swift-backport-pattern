#if canImport(SwiftUI)
import SwiftUI

/// Namespace access for SwiftUI views.
///
/// This extension only wraps a `View` in `Backport`. Consumer modules define and
/// own any concrete SwiftUI compatibility behavior added through constrained
/// `Backport` extensions.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension View {
    /// Exposes the view through the `Backport` namespace.
    ///
    /// This computed property wraps the view in a `Backport` struct so consumer
    /// modules can add constrained compatibility extensions without
    /// placing concrete API implementations in this package.
    ///
    /// ## Overview
    ///
    /// The package supplies only the wrapper. The consuming module is responsible
    /// for native and fallback branches, semantic differences, verification, and
    /// removal of every concrete extension.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let wrappedText = Text("Hello, World!").backport
    /// ```
    ///
    /// - Returns: A namespace wrapper around this view.
    ///
    /// - Note: This modifier is available only when SwiftUI can be imported,
    ///   ensuring compatibility across different platform targets.
    var backport: Backport<Self> { .init(self) }
}

#endif
