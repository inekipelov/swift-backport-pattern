# Backport Adoption Guide

Public engineering guide for adopting compatibility APIs with:

- `Backport<Content>` for instance-scoped APIs (`view.backport.newAPI(...)`)
- `Backported` namespace (`typealias Backported = Backport<Never>`) for compatibility types (`Backported.SomeType`)

This guide is written for maintainers and contributors, including AI coding agents.
This repository provides the pattern and guidance. Backport adoptions are expected to live in consumer app/package modules.

## 1. Scope and Goals

Backports implemented with this pattern MUST:

1. Preserve predictable behavior across supported OS versions.
2. Minimize migration cost when old OS support is removed.
3. Keep call sites stable and readable.
4. Isolate compatibility logic away from product feature code.
5. Provide a unified cross-version and cross-platform call site (for example, iOS has an API but tvOS does not) without scattering `if #available` or `#if os(...)` in production feature code.

Backports MUST NOT be introduced only to "make code compile" if semantics are unclear.

## 2. Decision Order

Choose an adoption strategy in this order:

1. Dummy fallback if behavior can safely degrade.
2. Redirect fallback to a near-equivalent older API.
3. `Backported` compatibility type if native types are unavailable.
4. Full polyfill/backfill if parity is required and steps 1-3 are insufficient.

If behavior affects correctness, accessibility, security, or data integrity, skip step 1 and move to step 2+.

## 3. Canonical Backport Categories

### 3.1 Dummy Fallback

Unsupported OS path returns unchanged `content` (or another benign default).

```swift
public extension Backport where Content: ToolbarContent {
    @ToolbarContentBuilder
    func sharedBackgroundVisibility(_ visibility: Visibility) -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.sharedBackgroundVisibility(visibility)
        } else {
            content
        }
    }
}
```

Use when:

1. API is progressive enhancement only.
2. Legacy behavior remains acceptable.

Do not use when:

1. Behavior is required for correctness or accessibility outcomes.
2. Removing the effect breaks interaction or layout expectations.

Required notes:

1. Document fallback as explicit no-op.
2. Document user-visible delta (if any).

### 3.2 Redirect Fallback

Unsupported OS path maps to an older API with similar semantics.

```swift
extension Backport where Content: View {
    @ViewBuilder
    public func safeAreaBar(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            self.content.safeAreaBar(edge: edge, alignment: alignment, spacing: spacing, content: content)
        } else {
            self.content.safeAreaInset(edge: edge, alignment: alignment, spacing: spacing, content: content)
        }
    }
}
```

Use when:

1. A near-equivalent API exists.
2. Parameter mapping can preserve behavior with a known semantic delta.

Required notes:

1. Document semantic delta explicitly.
2. Document unsupported parameter combinations (if any).

### 3.3 `Backported` Compatibility Types

Define compatibility model types under `Backported`, then bridge to native types when available.

```swift
public extension Backported {
    struct Glass: Sendable {
        // compatibility representation
    }
}

public extension Backport where Content: PrimitiveButtonStyle {
    @MainActor
    func glass(_ glass: Backported.Glass) -> some PrimitiveButtonStyle {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            return .glass(glass.swiftUIGlass)
        } else {
            return .bordered
        }
    }
}
```

Use when:

1. Native API introduces unavailable types on older OS versions.
2. Stable public call site is required now.

Required rules:

1. Compatibility types SHOULD be small, value-like, and explicit.
2. Invariants MUST be documented.
3. Native conversion MUST be guarded by availability.
4. Platform exclusions (`#if os(...)`) MUST be explicit.

### 3.4 Full Polyfill / Behavioral Backfill

Build custom legacy behavior when no safe no-op or redirect can preserve required semantics.

Pattern:

1. Native path for new OS.
2. Legacy path (`LegacyXView`, custom modifier, adapter/service) for old OS.
3. Single unified `Backport` entry point.

```swift
extension Backport where Content: View {
    @ViewBuilder
    func modernEffect(_ configuration: Backported.ModernEffectConfiguration) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            content.modernEffect(configuration.nativeConfiguration)
        } else {
            LegacyModernEffectView(
                base: content,
                configuration: configuration
            )
        }
    }
}
```

Use when:

1. Feature parity is required.
2. Silent degradation is unacceptable.

Trade-off:

- Highest maintenance cost.

## 4. API Design Rules

1. Public names SHOULD mirror Apple naming where practical.
2. Instance behavior MUST live in `extension Backport where Content: ...`.
3. Type-like compatibility constructs MUST live under `Backported`.
4. Avoid unrelated convenience APIs in backport modules.
5. Keep wrappers explicit (`content`) and avoid hidden magic behavior.
6. Availability and platform branching SHOULD be encapsulated inside the backport layer, not repeated at call sites.

## 5. SwiftUI Rules

1. Availability checks SHOULD stay at modifier boundaries, not spread through feature views.
2. Both availability branches MUST return structurally valid view content.
3. Fallback behavior for platform gaps (for example, visionOS) MUST be explicit and documented.
4. Avoid runtime-conditional hierarchy changes inside wrappers unless intentionally tested.

## 6. Usage Workflow (For Consumer Repositories)

For each new backport in your app or library:

1. Classify the backport approach as `3.1`, `3.2`, `3.3`, or `3.4`.
2. Implement under your local module using `Backport`/`Backported` conventions from this guide.
3. Document fallback behavior and semantic delta in API docs.
4. Add tests for:
   - compile-time availability branching
   - old OS fallback behavior (or best feasible proxy)
   - new OS native path behavior
5. Add or update usage examples in your own repository docs.
6. Define the removal plan for when your minimum OS reaches native availability.
7. Verify that production feature code can call a single unified API without local `if #available` / `#if os(...)` branching for that feature.

## 7. Testing Minimum

Every public backport API MUST have:

1. A compile-time coverage test for availability branches.
2. At least one behavior assertion for fallback path.
3. At least one behavior assertion for native path (when feasible).
4. A source-stability check for public entry points (`.backport.` and `Backported.` usage).

## 8. Upgrade and Removal

When minimum OS >= native API availability:

1. Remove compatibility shim.
2. Replace backport call sites with native APIs as appropriate.
3. Remove obsolete tests and docs.
4. Keep compatibility types only if they still provide product value outside compatibility.

## 9. Anti-Patterns

1. Undocumented behavior differences between OS branches.
2. Reusing one wrapper API for unrelated semantics.
3. No-op fallbacks for correctness-critical features.
4. Introducing compatibility helpers with no clear deprecation/removal path.

## 10. References

- Dave DeLong, "Simplifying Backwards Compatibility in Swift":
  - https://davedelong.com/blog/2021/10/09/simplifying-backwards-compatibility-in-swift/
- SwiftUI Garden, "Handling different iOS versions in a View body":
  - https://swiftui-garden.com/Articles/Handling-different-iOS-versions-in-a-View-body
