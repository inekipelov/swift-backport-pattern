# Backport

`Backport` is a tiny Swift Package that implements the backport pattern as a
small, reusable wrapper.

The design is inspired by [Dave DeLong’s write-up on backwards
compatibility](https://davedelong.com/blog/2021/10/09/simplifying-backwards-compatibility-in-swift/).

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.0+-F05138?logo=swift&logoColor=white" alt="Swift 5.0+"></a>
  <a href="https://developer.apple.com/ios/"><img src="https://img.shields.io/badge/iOS-9.0+-000000?logo=apple" alt="iOS 9.0+"></a>
  <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-10.13+-000000?logo=apple" alt="macOS 10.13+"></a>
  <a href="https://developer.apple.com/tvos/"><img src="https://img.shields.io/badge/tvOS-9.0+-000000?logo=apple" alt="tvOS 9.0+"></a>
  <a href="https://developer.apple.com/watchos/"><img src="https://img.shields.io/badge/watchOS-2.0+-000000?logo=apple" alt="watchOS 2.0+"></a>
  <a href="https://developer.apple.com/visionos/"><img src="https://img.shields.io/badge/visionOS-1.0+-000000?logo=apple" alt="visionOS 1.0+"></a>

</p>

## Usage

```swift
import Backport

// Basic usage
let view = MyView()
view.backport.modernFeature()

// SwiftUI
Text("Hello")
    .backport.modernModifier()

// Custom extensions
extension Backport where Content: UIView {
    func modernShadow() -> Content {
        // Implementation
        return content
    }
}
```

## Adoption Guide

Implementation and usage guidance is documented in:

- [Backport Adoption Guide](docs/BACKPORT_ADOPTION_GUIDE.md)

Agent designation (machine-readable):

`AGENT-DOC: BACKPORT_ADOPTION_GUIDE -> docs/BACKPORT_ADOPTION_GUIDE.md`

<!-- AGENT-DOC: BACKPORT_ADOPTION_GUIDE -> docs/BACKPORT_ADOPTION_GUIDE.md -->

## Installation

Add the package to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/inekipelov/swift-backport-pattern.git", from: "0.2.0")
```
