import Foundation
import XCTest
@testable import Backport

#if canImport(SwiftUI)
import SwiftUI
#endif

private struct DocumentationValue {
    let title: String
}

private extension Backport where Content == DocumentationValue {
    var normalizedTitle: String {
        content.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

#if canImport(SwiftUI)
@available(iOS 99.0, macOS 99.0, tvOS 99.0, watchOS 99.0, *)
private extension View {
    func documentationNativeEffect() -> some View {
        opacity(1)
    }
}

private extension Backported {
    struct DocumentationEffect {
        let opacity: Double
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private struct LegacyDocumentationEffect<Content: View>: View {
    let content: Content

    var body: some View {
        content.opacity(0.9)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private extension Backport where Content: View {
    // redirect-fallback: use a near-equivalent legacy API.
    @ViewBuilder
    func documentationRedirectEffect() -> some View {
        if #available(iOS 99.0, macOS 99.0, tvOS 99.0, watchOS 99.0, *) {
            content.documentationNativeEffect()
        } else {
            content.opacity(1)
        }
    }

    // compatibility-type: expose an unavailable configuration shape under Backported.
    func documentationCompatibilityEffect(
        _ effect: Backported.DocumentationEffect
    ) -> some View {
        content.opacity(effect.opacity)
    }

    // behavioral-polyfill: use custom legacy behavior when a redirect is insufficient.
    @ViewBuilder
    func documentationPolyfillEffect() -> some View {
        if #available(iOS 99.0, macOS 99.0, tvOS 99.0, watchOS 99.0, *) {
            content.documentationNativeEffect()
        } else {
            LegacyDocumentationEffect(content: content)
        }
    }

    // no-op-fallback: return unchanged content only for safe progressive enhancement.
    @ViewBuilder
    func documentationNoOpEffect() -> some View {
        if #available(iOS 99.0, macOS 99.0, tvOS 99.0, watchOS 99.0, *) {
            content.documentationNativeEffect()
        } else {
            content
        }
    }
}
#endif

final class DocumentationExamplesTests: XCTestCase {
    func testConstrainedBackportExtensionUsesWrappedContent() {
        let value = DocumentationValue(title: "  Hello Backport  ")

        XCTAssertEqual(Backport(value).normalizedTitle, "hello backport")
    }

    #if canImport(SwiftUI)
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func testSwiftUICategoryExamplesCompile() {
        let view = Text("Backport")

        _ = view.backport.documentationRedirectEffect()
        _ = view.backport.documentationCompatibilityEffect(
            .init(opacity: 0.8)
        )
        _ = view.backport.documentationPolyfillEffect()
        _ = view.backport.documentationNoOpEffect()
    }
    #endif
}
