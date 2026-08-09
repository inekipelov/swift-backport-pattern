# Backport Adoption Guide

Use this compact engineering guide to adopt compatibility APIs with:

- `Backport<Content>` for instance APIs: `view.backport.someAPI(...)`
- `Backported` (`Backport<Never>`) for compatibility types: `Backported.SomeType`

This is a consumer adoption guide. This repository defines and tests the
namespace pattern only. Do not add concrete Apple API backports to this
package's `Sources/`. Concrete implementations, semantic decisions, evidence,
ownership, and removal records belong in consumer app or package modules.

## 1. Scope

Before selecting a category, confirm that the target is a consumer repository
with product and platform context. A request targeting this pattern package
must be redirected to the consumer rather than implemented here.

Every backport must:

1. Preserve predictable behavior across supported OS versions.
2. Keep call sites stable and readable.
3. Isolate compatibility branching away from feature code.
4. Minimize removal cost when old OS support is dropped.
5. Provide one unified call site across OS and platform differences.

Do not introduce a backport only to make code compile when its semantics are unclear.

## 2. Decision Matrix

Evaluate categories in this order:

1. `redirect-fallback`
2. `compatibility-type`
3. `behavioral-polyfill`
4. `no-op-fallback`

A `no-op-fallback` is forbidden when degradation can affect correctness, accessibility, security, or data integrity.

| Category | Use when | Do not use when | Required evidence |
| --- | --- | --- | --- |
| `redirect-fallback` | A near-equivalent legacy API exists and parameter mapping preserves user outcomes except explicit deltas | The remaining semantic drift is unacceptable | Document every semantic delta and unsupported parameter combination |
| `compatibility-type` | The native API requires types unavailable on older OS versions and a stable call site is needed | Type invariants cannot be represented explicitly | Document invariants, availability-guarded native conversion, and platform exclusions |
| `behavioral-polyfill` | Required behavior cannot accept redirect or no-op deltas | The team cannot own its implementation and removal cost | Document complexity, owner, validation, removal trigger, and migration path |
| `no-op-fallback` | The feature is progressive enhancement and unchanged legacy behavior is a safe degrade | Any required outcome, interaction, or layout contract can break | Prove the degrade is safe and document the user-visible delta |

Definitions:

- **Near-equivalent:** equivalent user outcomes except for explicitly documented deltas.
- **Safe degrade:** no effect on correctness, accessibility, security, or data integrity, with acceptable interaction and layout differences.
- **Required parity:** documented fallback deltas are not acceptable for the product or platform contract.

## 3. Source-Grounded Compiled Examples

The following examples are reduced from the consumer-owned
[`swiftui-liquid-glass-backport`](https://github.com/inekipelov/swiftui-liquid-glass-backport)
implementations. Their executable adaptations live in
[`Tests/DocumentationExamples.swift`](../Tests/DocumentationExamples.swift),
and the complete category-oriented examples are available to agents in the
[`swiftui-backport-adoption` reference](../.agents/skills/swiftui-backport-adoption/references/category-examples.md).

| Category | Consumer API | Why it fits | Explicit fallback delta |
| --- | --- | --- | --- |
| `redirect-fallback` | `View.backport.safeAreaBar` | Redirects to the legacy `safeAreaInset` API | Keeps the bar and reserved layout space, but not native progressive blur |
| `compatibility-type` | `Backported.SearchToolbarBehavior` | Stores cases without constructing unavailable `SwiftUI.SearchToolbarBehavior` | Native conversion exists only behind Apple OS 26 availability; platform-specific cases remain explicit |
| `behavioral-polyfill` | `View.backport.glassEffect` | Builds custom legacy behavior from material, tint, border, clipping, and shadow on iOS, macOS, tvOS, and watchOS | Approximates native rendering and interaction; the consumer's visionOS branch is a separately documented no-op |
| `no-op-fallback` | `View.backport.backgroundExtensionEffect` | The effect is progressive enhancement | Returns the original view before Apple OS 26 and provides no background extension effect |

The README shows each unified call site. The fixtures prove that those API
shapes and availability-gated native branches compile on the current SDK; they
do not prove visual, interaction, accessibility, or fallback-runtime behavior.

The original `View.badge(_:)` fixture remains a second `no-op-fallback`
example. It is valid only when the badge is supplementary; a required status,
navigation cue, accessibility value, or action needs another fallback.

## 4. Mandatory Decision Record

Create a decision record for every public backport. For internal backports, use the same record whenever fallback behavior can affect a user or more than one module.

Start from the [Backport Decision Record](../.agents/skills/swiftui-backport-adoption/assets/backport-decision-record.md) and record:

1. Lifecycle status, native API, availability, consumer deployment targets, and supported platforms.
2. Selected semantic category and rejected alternatives.
3. Native and fallback behavior, including semantic deltas.
4. Correctness, accessibility, security, data-integrity, interaction, and layout risk.
5. Platform/OS validation matrix and unexecutable gaps.
6. Owner, decision date, removal trigger, and target release for any deferral.

## 5. Implementation Rules

1. Implement the concrete API in a consumer-owned module, never in this package target.
2. Mirror Apple naming where practical without claiming unsupported parity.
3. Put instance behavior in `extension Backport where Content: ...`.
4. Put compatibility types under `Backported`.
5. Keep availability and platform branching inside the backport layer.
6. Return structurally valid content from every SwiftUI branch.
7. Make platform gaps explicit, including platforms that the consumer does not support.
8. Keep compatibility types small and value-like; document their invariants.
9. Guard every native conversion with the matching availability condition.
10. Keep unrelated convenience APIs outside the backport layer.
11. Document semantic deltas in API documentation and the decision record.

## 6. Verification Gate

Every public backport requires:

1. Compile coverage for native and fallback branches.
2. At least one fallback behavior assertion or the strongest feasible proxy.
3. At least one native behavior assertion when the native runtime is available.
4. Source-stability coverage for the unified `.backport.` or `Backported.` call site.
5. A platform/OS matrix that records `native`, `fallback`, both, or unexecuted for each supported platform.
6. Explicit proxy evidence and confidence limits for branches CI cannot execute.

Compilation proves only type and availability correctness. It does not prove visual, interaction, accessibility, or data behavior.

## 7. Upgrade and Removal

When every supported deployment target reaches the native API's availability:

1. Replace backport call sites with the native API while preserving behavior.
2. Remove the compatibility shim, fallback, bridges, and legacy helpers.
3. Remove obsolete tests and documentation; retain native behavior coverage.
4. Keep a compatibility type only when it still has product value independent of compatibility.
5. Remove the package dependency only after repository-wide searches prove no other uses remain.
6. Close the decision record with removal evidence, release, and validation matrix.

Complete removal in the first release cycle after the deployment-target change. Record a reason and target release for any deferral.

## 8. Anti-Patterns

1. Undocumented differences between native and fallback branches.
2. One wrapper API representing unrelated semantics.
3. No-op fallback for a required or accessibility-relevant outcome without neutrality evidence.
4. Compatibility helper with no owner or removal trigger.
5. Feature-level availability checks duplicated around a unified backport API.
6. Documentation examples that look executable but omit required types or conversions.

## 9. References

- Dave DeLong, [Simplifying Backwards Compatibility in Swift](https://davedelong.com/blog/2021/10/09/simplifying-backwards-compatibility-in-swift/)
- SwiftUI Garden, [Handling different iOS versions in a View body](https://swiftui-garden.com/Articles/Handling-different-iOS-versions-in-a-View-body)
- Apple, [`View.badge(_:)`](https://developer.apple.com/documentation/swiftui/view/badge(_:)-8adyq)
