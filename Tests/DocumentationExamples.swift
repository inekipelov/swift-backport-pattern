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

final class DocumentationExamplesTests: XCTestCase {
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func testUnreadBadgeExampleCompiles() {
        _ = DocumentationInboxTab(unreadCount: 42).body
    }
}
#endif
