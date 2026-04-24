/// A generic wrapper that provides backport functionality for any type.
///
/// The `Backport` struct wraps content while enabling the addition of backport
/// functionality through constrained extensions.
///
/// ## Overview
///
/// This struct serves as the foundation for the backport system, allowing you to
/// add modern API features to older versions of frameworks. It wraps any content
/// and provides access to the original content via `content`.
///
/// ## Usage
///
/// ```swift
/// let view = MyView()
/// let backportedView = view.backport
/// ```
///
public struct Backport<Content> {
    /// The wrapped content that will receive backport functionality.
    ///
    /// This property holds the original content that the backport wraps,
    /// providing access to all of its original functionality while enabling
    /// the addition of backport features.
    public let content: Content

    /// Creates a new backport wrapper around the provided content.
    ///
    /// - Parameter content: The content to wrap with backport functionality.
    public init(_ content: Content) {
        self.content = content
    }
}
