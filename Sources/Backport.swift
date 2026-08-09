/// A generic wrapper that establishes a namespace for consumer-defined
/// compatibility APIs.
///
/// The `Backport` struct stores content and gives consumer modules a stable
/// extension point through constrained extensions. This package does not add
/// concrete framework API backports to the namespace.
///
/// ## Overview
///
/// This struct is the foundation of the namespace pattern. It wraps any content
/// and exposes the original value through `content`; consumers own the behavior,
/// fallback semantics, and lifecycle of extensions they add.
///
/// ## Usage
///
/// ```swift
/// let wrappedValue = Backport("Example")
/// print(wrappedValue.content)
/// ```
///
public struct Backport<Content> {
    /// The wrapped content exposed through the compatibility namespace.
    ///
    /// This property holds the original content that the backport wraps,
    /// providing access to its original behavior from consumer-defined
    /// constrained extensions.
    public let content: Content

    /// Creates a new backport wrapper around the provided content.
    ///
    /// - Parameter content: The content to expose through the namespace.
    public init(_ content: Content) {
        self.content = content
    }
}
