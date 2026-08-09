# SwiftUI Backport Category Examples

These reduced examples come from the consumer-owned
[`swiftui-liquid-glass-backport`](https://github.com/inekipelov/swiftui-liquid-glass-backport).
They are reference shapes, not APIs shipped by `swift-backport-pattern`.
Recheck SDK declarations, deployment targets, supported platforms, and product
semantics before adapting one.

All snippets assume `import SwiftUI` and `import Backport`.

## Contents

- [`redirect-fallback`](#redirect-fallback)
- [`compatibility-type`](#compatibility-type)
- [`behavioral-polyfill`](#behavioral-polyfill)
- [`no-op-fallback`](#no-op-fallback)

## `redirect-fallback`

Redirect `safeAreaBar` to the older `safeAreaInset`. This preserves the bar and
reserved layout space, but not Apple OS 26 progressive blur.

```swift
@available(iOS 15.0, macOS 12.0, tvOS 15.0,
           watchOS 8.0, visionOS 1.0, *)
public extension Backport where Content: View {
    @ViewBuilder
    func safeAreaBar<Bar: View>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content barContent: () -> Bar
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0,
                      watchOS 26.0, visionOS 26.0, *) {
            content.safeAreaBar(
                edge: edge,
                alignment: alignment,
                spacing: spacing,
                content: barContent
            )
        } else {
            content.safeAreaInset(
                edge: edge,
                alignment: alignment,
                spacing: spacing,
                content: barContent
            )
        }
    }
}

ScrollView { Text("Results") }
    .backport.safeAreaBar(edge: .bottom) {
        Button("Show filters") {}
    }
```

Reject this redirect if progressive blur or another native-only semantic is a
required product outcome.

## `compatibility-type`

Store a value-like representation without constructing the unavailable native
type. Expose native conversion only behind matching availability.

```swift
public extension Backported {
    struct SearchToolbarBehavior: Hashable, Sendable {
        fileprivate enum Variant: Hashable, Sendable {
            case automatic
            case minimize
        }

        fileprivate let variant: Variant

        public static var automatic: Self { Self(variant: .automatic) }

        @available(macOS, unavailable)
        @available(tvOS, unavailable)
        @available(watchOS, unavailable)
        public static var minimize: Self { Self(variant: .minimize) }

        @available(iOS 26.0, macOS 26.0, tvOS 26.0,
                   watchOS 26.0, visionOS 26.0, *)
        fileprivate var swiftUIValue: SwiftUI.SearchToolbarBehavior {
            switch variant {
            case .automatic:
                .automatic
            case .minimize:
                #if os(iOS) || os(visionOS)
                .minimize
                #else
                .automatic
                #endif
            }
        }
    }
}

public extension Backport where Content: View {
    @ViewBuilder
    func searchToolbarBehavior(
        _ behavior: Backported.SearchToolbarBehavior
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0,
                      watchOS 26.0, visionOS 26.0, *) {
            content.searchToolbarBehavior(behavior.swiftUIValue)
        } else {
            content
        }
    }
}

let behavior: Backported.SearchToolbarBehavior = .automatic
Text("Search results")
    .backport.searchToolbarBehavior(behavior)
```

Document every invariant and unavailable platform case. This type is the
`compatibility-type` slice; assess the consuming modifier's no-op behavior as a
separate compatibility decision.

## `behavioral-polyfill`

Build a legacy approximation when redirect and no-op behavior cannot satisfy
the product. This reduced `glassEffect` polyfill targets Material-capable
iOS, macOS, tvOS, and watchOS floors. The source consumer treats visionOS as a
separate no-op branch, which must remain explicit in its platform matrix.

```swift
public extension Backported {
    struct Glass: Sendable {
        fileprivate let tintColor: Color?

        public static var regular: Self { Self(tintColor: nil) }

        public func tint(_ color: Color?) -> Self {
            Self(tintColor: color)
        }

        fileprivate var fallbackColor: Color {
            (tintColor ?? .white).opacity(tintColor == nil ? 0.06 : 0.18)
        }

        fileprivate var edgeColor: Color {
            (tintColor ?? .white).opacity(tintColor == nil ? 0.28 : 0.32)
        }

        fileprivate var shadowColor: Color { .black.opacity(0.14) }

        #if !os(visionOS)
        @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
        fileprivate var swiftUIValue: SwiftUI.Glass {
            SwiftUI.Glass.regular.tint(tintColor)
        }
        #endif
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 10.0, *)
public extension Backport where Content: View {
    @ViewBuilder
    func glassEffect<S: Shape>(
        _ glass: Backported.Glass = .regular,
        in shape: S = Capsule()
    ) -> some View {
        #if os(visionOS)
        content
        #else
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            content.glassEffect(glass.swiftUIValue, in: shape)
        } else {
            content
                .background {
                    shape
                        .fill(Material.regular)
                        .overlay(shape.fill(glass.fallbackColor))
                }
                .clipShape(shape)
                .overlay(shape.stroke(glass.edgeColor, lineWidth: 0.5))
                .shadow(color: glass.shadowColor, radius: 8, y: 2)
        }
        #endif
    }
}

Text("Featured")
    .backport.glassEffect(
        .regular.tint(.blue),
        in: RoundedRectangle(cornerRadius: 12)
    )
```

This reproduces a hierarchy of material, tint, clipping, edge, and depth. It
does not reproduce native Liquid Glass rendering or interaction; visual and
accessibility verification are required.

## `no-op-fallback`

Return the original view only when the native effect is optional progressive
enhancement and its absence cannot change a required outcome.

```swift
public extension Backport where Content: View {
    @ViewBuilder
    func backgroundExtensionEffect() -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0,
                      watchOS 26.0, visionOS 26.0, *) {
            content.backgroundExtensionEffect()
        } else {
            content
        }
    }
}

Image(systemName: "photo")
    .backport.backgroundExtensionEffect()
```

Reject this category when the effect affects correctness, accessibility,
security, data integrity, required interaction, or required layout.
