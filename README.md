# Backport

[![Swift Version](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift Tests](https://github.com/inekipelov/swift-backport/actions/workflows/swift.yml/badge.svg)](https://github.com/inekipelov/swift-backport/actions/workflows/swift.yml)  
[![iOS](https://img.shields.io/badge/iOS-9.0+-blue.svg)](https://developer.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-10.13+-white.svg)](https://developer.apple.com/macos/)
[![tvOS](https://img.shields.io/badge/tvOS-9.0+-black.svg)](https://developer.apple.com/tvos/)
[![watchOS](https://img.shields.io/badge/watchOS-2.0+-orange.svg)](https://developer.apple.com/watchos/)

A Swift library that provides seamless backward compatibility for modern APIs on older OS versions.  

It’s based on [Dave DeLong’s elegant approach](https://davedelong.com/blog/2021/10/09/simplifying-backwards-compatibility-in-swift/) to backwards compatibility in Swift. Definitely read that before diving in.


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

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/inekipelov/swift-backport", from: "0.1.0")
]
```

## License

MIT License - see [LICENSE](LICENSE) file for details.
