/// A generic wrapper that provides backport functionality for any type.
///
/// The `Backport` struct uses `@dynamicMemberLookup` to provide seamless access
/// to the wrapped content's properties while enabling the addition of backport
/// functionality through extensions.
///
/// ## Overview
///
/// This struct serves as the foundation for the backport system, allowing you to
/// add modern API features to older versions of frameworks. It wraps any content
/// and provides transparent access to the original content's properties.
///
/// ## Usage
///
/// ```swift
/// let view = MyView()
/// let backportedView = view.backport
/// ```
///
/// - Note: This struct uses dynamic member lookup to forward property access
///   to the wrapped content, making it transparent to use.
@dynamicMemberLookup
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

    /// Provides dynamic member lookup access to the wrapped content's properties.
    ///
    /// This subscript enables transparent access to any property of the wrapped
    /// content using key paths, making the backport wrapper feel invisible to users.
    ///
    /// - Parameter keyPath: A key path to a property on the wrapped content.
    /// - Returns: The value of the property at the specified key path.
    public subscript<T>(dynamicMember keyPath: KeyPath<Content, T>) -> T {
        content[keyPath: keyPath]
    }
}