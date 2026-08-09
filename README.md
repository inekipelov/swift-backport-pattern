# Backport

`Backport` is a tiny Swift Package that implements the backport pattern as a
small, reusable namespace. It does not ship concrete Apple API backports.

The design is inspired by [Dave DeLong’s write-up on backwards
compatibility](https://davedelong.com/blog/2021/10/09/simplifying-backwards-compatibility-in-swift/).

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.0+-F05138?logo=swift&logoColor=white" alt="Swift 5.0+"></a>
  <a href="https://developer.apple.com/ios/"><img src="https://img.shields.io/badge/iOS-9.0+-CAFC63?logo=apple" alt="iOS 9.0+"></a>
  <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-10.13+-CAFC63?logo=apple" alt="macOS 10.13+"></a>
  <a href="https://developer.apple.com/tvos/"><img src="https://img.shields.io/badge/tvOS-9.0+-CAFC63?logo=apple" alt="tvOS 9.0+"></a>
  <a href="https://developer.apple.com/watchos/"><img src="https://img.shields.io/badge/watchOS-2.0+-CAFC63?logo=apple" alt="watchOS 2.0+"></a>
  <a href="https://developer.apple.com/visionos/"><img src="https://img.shields.io/badge/visionOS-1.0+-CAFC63?logo=apple" alt="visionOS 1.0+"></a>

</p>

## Usage

The package owns the reusable namespace mechanism: `Backport<Content>`, the
`Backported` type namespace, and `.backport` access for supported framework
types. Consumer modules own every concrete compatibility API, its native and
fallback behavior, validation, and eventual removal.

For example, an app that supports iOS 14 can keep one call site for the real
SwiftUI [`View.badge(_:)`](https://developer.apple.com/documentation/swiftui/view/badge(_:)-8adyq)
API. This consumer-owned shim is appropriate only when the unread count is
supplementary; it must not hide a required status or action on older systems.

```swift
import SwiftUI
import Backport

extension Backport where Content: View {
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

struct InboxTabs: View {
    let unreadCount: Int

    var body: some View {
        TabView {
            Text("Inbox")
                .tabItem { Label("Inbox", systemImage: "tray") }
                .backport.badge(unreadCount)
        }
    }
}
```

The native API is available on iOS/iPadOS and Mac Catalyst 15, macOS 12, and
visionOS 1. On older or unsupported platforms the shim returns the original
view unchanged. The executable copy lives in
[`Tests/DocumentationExamples.swift`](Tests/DocumentationExamples.swift); it is
a consumer-reference implementation, not an API shipped by this package.

The four categories have concrete consumer examples adapted from
[`swiftui-liquid-glass-backport`](https://github.com/inekipelov/swiftui-liquid-glass-backport):

| Category | Example | Fallback contract |
| --- | --- | --- |
| `redirect-fallback` | `.backport.safeAreaBar` | Use `safeAreaInset`; preserve the bar and layout space, but not progressive blur |
| `compatibility-type` | `Backported.SearchToolbarBehavior` | Store a value-like representation and bridge it to SwiftUI only on Apple OS 26+ |
| `behavioral-polyfill` | `.backport.glassEffect` | On legacy iOS, macOS, tvOS, and watchOS, rebuild the visual hierarchy with material, tint, border, and shadow; visionOS remains unchanged |
| `no-op-fallback` | `.backport.backgroundExtensionEffect` | Preserve the original view when the effect is only progressive enhancement |

```swift
ScrollView { Text("Results") }
    .backport.safeAreaBar(edge: .bottom) {
        Button("Show filters") {}
    }

let behavior: Backported.SearchToolbarBehavior = .automatic
Text("Search results")
    .backport.searchToolbarBehavior(behavior)

Text("Featured")
    .backport.glassEffect(
        .regular.tint(.blue),
        in: RoundedRectangle(cornerRadius: 12)
    )

Image(systemName: "photo")
    .backport.backgroundExtensionEffect()
```

These APIs remain consumer-owned; the package ships only their namespace.
Their complete implementations live in the
[`swiftui-backport-adoption` reference](.agents/skills/swiftui-backport-adoption/references/category-examples.md).
SDK-independent fallback and call-site fixtures live in
[`Tests/DocumentationExamples.swift`](Tests/DocumentationExamples.swift).

## Documentation

Use the guide that matches the task:

- [Contributing](CONTRIBUTING.md)
- [Documentation Map](docs/README.md)
- [Backport Adoption Guide](docs/BACKPORT_ADOPTION_GUIDE.md)
- [AI Agent Adoption](docs/AI_AGENT_ADOPTION.md)

## Installation

Add the package to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/inekipelov/swift-backport-pattern.git", from: "0.2.0")
```
