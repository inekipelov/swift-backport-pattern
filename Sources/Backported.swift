/// A marker namespace that consumer modules extend with compatibility types.
///
/// The package defines the namespace only. Concrete types and their native
/// conversions belong to the consumer that owns the compatibility behavior.
public typealias Backported = Backport<Never>
