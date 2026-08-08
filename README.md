# Backport

`Backport` is a tiny Swift Package that implements the backport pattern as a
small, reusable wrapper.

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

The package provides a namespace pattern. Consumer modules define the concrete
compatibility APIs they need:

```swift
import Foundation
import Backport

struct Article {
    let title: String
}

extension Backport where Content == Article {
    var normalizedTitle: String {
        content.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

let title = Backport(Article(title: "  News  ")).normalizedTitle
```

An executable version of this pattern lives in
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
