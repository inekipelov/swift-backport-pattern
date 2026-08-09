import XCTest
@testable import Backport

#if canImport(SwiftUI)
import SwiftUI

// A consumer-owned compatibility shim for SwiftUI's View.badge(_:), which is
// available on iOS 15, macOS 12, and visionOS 1. The fallback is suitable only
// when the unread-count badge is optional, supplementary information.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private extension Backport where Content: View {
    @ViewBuilder
    func badge(_ count: Int) -> some View {
        #if os(iOS) || os(macOS) || os(visionOS)
        if #available(iOS 15.0, macOS 12.0, visionOS 1.0, *) {
            content.badge(count)
        } else {
            content
        }
        #else
        content
        #endif
    }

    // Redirect fallback: older systems keep the bar and its reserved layout
    // space through safeAreaInset, without claiming the native visual effect.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    @ViewBuilder
    func safeAreaBar<Bar: View>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content barContent: () -> Bar
    ) -> some View {
        content.safeAreaInset(
            edge: edge,
            alignment: alignment,
            spacing: spacing,
            content: barContent
        )
    }

    // Compatibility-type consumer: the call site can name a behavior before
    // SwiftUI.SearchToolbarBehavior is available at the deployment target.
    @ViewBuilder
    func searchToolbarBehavior(
        _: Backported.SearchToolbarBehavior
    ) -> some View {
        content
    }

    // Behavioral polyfill: approximate Liquid Glass with a material, tint,
    // border, and shadow when the native effect is unavailable.
    @ViewBuilder
    func glassEffect<S: Shape>(
        _ glass: Backported.Glass = .regular,
        in shape: S = Capsule()
    ) -> some View {
        #if os(visionOS)
        content
        #else
        if #available(
            iOS 15.0,
            macOS 12.0,
            tvOS 15.0,
            watchOS 10.0,
            *
        ) {
            content
                .background {
                    shape
                        .fill(Material.regular)
                        .overlay(shape.fill(glass.fallbackColor))
                }
                .clipShape(shape)
                .overlay(shape.stroke(glass.edgeColor, lineWidth: 0.5))
                .shadow(color: glass.shadowColor, radius: 8, y: 2)
        } else {
            content
                .background(glass.fallbackColor)
                .clipShape(shape)
                .overlay(shape.stroke(glass.edgeColor, lineWidth: 0.5))
                .shadow(color: glass.shadowColor, radius: 8, y: 2)
        }
        #endif
    }

    // No-op fallback: the native modifier is progressive enhancement, so
    // earlier systems keep the original content unchanged.
    @ViewBuilder
    func backgroundExtensionEffect() -> some View {
        content
    }
}

private extension Backported {
    struct SearchToolbarBehavior: Hashable, Sendable {
        fileprivate enum Variant: Hashable, Sendable {
            case automatic
            case minimize
        }

        fileprivate let variant: Variant

        static var automatic: Self { Self(variant: .automatic) }

        @available(macOS, unavailable)
        @available(tvOS, unavailable)
        @available(watchOS, unavailable)
        static var minimize: Self { Self(variant: .minimize) }
    }

    struct Glass: Sendable {
        fileprivate let tintColor: Color?

        static var regular: Self { Self(tintColor: nil) }

        func tint(_ color: Color?) -> Self {
            Self(tintColor: color)
        }

        fileprivate var fallbackColor: Color {
            (tintColor ?? .white).opacity(tintColor == nil ? 0.06 : 0.18)
        }

        fileprivate var edgeColor: Color {
            (tintColor ?? .white).opacity(tintColor == nil ? 0.28 : 0.32)
        }

        fileprivate var shadowColor: Color {
            Color.black.opacity(0.14)
        }
    }
}

private struct DocumentationInboxTab: View {
    let unreadCount: Int

    var body: some View {
        TabView {
            Text("Inbox")
                .tabItem {
                    Label("Inbox", systemImage: "tray")
                }
                .backport.badge(unreadCount)
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
private struct DocumentationSafeAreaScreen: View {
    var body: some View {
        ScrollView {
            Text("Results")
        }
        .backport.safeAreaBar(edge: .bottom) {
            Button("Show filters") {}
        }
    }
}

private struct DocumentationSearchScreen: View {
    var body: some View {
        Text("Search results")
            .backport.searchToolbarBehavior(.automatic)
    }
}

private struct DocumentationGlassEffectScreen: View {
    var body: some View {
        Text("Featured")
            .padding()
            .backport.glassEffect(
                .regular.tint(.blue),
                in: RoundedRectangle(cornerRadius: 12)
            )
    }
}

private struct DocumentationBackgroundExtensionScreen: View {
    var body: some View {
        Image(systemName: "photo")
            .backport.backgroundExtensionEffect()
    }
}

final class DocumentationExamplesTests: XCTestCase {
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func testUnreadBadgeExampleCompiles() {
        _ = DocumentationInboxTab(unreadCount: 42).body
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    func testSafeAreaBarExampleCompiles() {
        _ = DocumentationSafeAreaScreen().body
    }

    func testSearchToolbarBehaviorExampleCompiles() {
        let behavior: Backported.SearchToolbarBehavior = .automatic
        _ = behavior
        _ = DocumentationSearchScreen().body
    }

    func testGlassEffectPolyfillExampleCompiles() {
        _ = DocumentationGlassEffectScreen().body
    }

    func testBackgroundExtensionNoOpExampleCompiles() {
        _ = DocumentationBackgroundExtensionScreen().body
    }
}
#endif
