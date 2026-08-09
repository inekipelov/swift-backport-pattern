# Backport Adoption Guide

Use this compact engineering guide to adopt compatibility APIs with:

- `Backport<Content>` for instance APIs: `view.backport.someAPI(...)`
- `Backported` (`Backport<Never>`) for compatibility types: `Backported.SomeType`

This is a consumer adoption guide. This repository defines and tests the
namespace pattern only. Do not add concrete Apple API backports to this
package's `Sources/`. Concrete implementations, semantic decisions, evidence,
ownership, and removal records belong in consumer app or package modules.

For the normative repeatable AI workflow, use the
[`swiftui-backport-adoption` skill](../.agents/skills/swiftui-backport-adoption/SKILL.md).
This guide provides developer-facing rationale and examples; it does not
override that workflow.

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

## 3. Source-Grounded Examples

The following examples are reduced from the consumer-owned
[`swiftui-liquid-glass-backport`](https://github.com/inekipelov/swiftui-liquid-glass-backport)
implementations. Their complete category-oriented examples are available in the
[`swiftui-backport-adoption` reference](../.agents/skills/swiftui-backport-adoption/references/category-examples.md).

| Category | Consumer API | Why it fits | Explicit fallback delta |
| --- | --- | --- | --- |
| `redirect-fallback` | `View.backport.safeAreaBar` | Redirects to the legacy `safeAreaInset` API | Keeps the bar and reserved layout space, but not native progressive blur |
| `compatibility-type` | `Backported.SearchToolbarBehavior` | Stores cases without constructing unavailable `SwiftUI.SearchToolbarBehavior` | Native conversion exists only behind Apple OS 26 availability; platform-specific cases remain explicit |
| `behavioral-polyfill` | `View.backport.glassEffect` | Builds custom legacy behavior from material, tint, border, clipping, and shadow on iOS, macOS, tvOS, and watchOS | Approximates native rendering and interaction; the consumer's visionOS branch is a separately documented no-op |
| `no-op-fallback` | `View.backport.backgroundExtensionEffect` | The effect is progressive enhancement | Returns the original view before Apple OS 26 and provides no background extension effect |

The README shows each unified call site. These examples are reference material,
not package validation. Native and fallback branches must be compiled and
verified in the consumer repository against its supported SDKs and deployment
targets. Compilation alone does not prove visual, interaction, accessibility,
or fallback-runtime behavior.

The `View.badge(_:)` reference in the README is a second `no-op-fallback`
example. It is valid only when the badge is supplementary; a required status,
navigation cue, accessibility value, or action needs another fallback.

## 4. Mandatory Decision Record

Create one decision record for every independently removable compatibility
decision, including internal decisions. When a `Backported` type and its
consuming modifier can be removed independently, create separate cross-linked
records with their own categories and removal triggers.

Start from the [Backport Decision Record](../.agents/skills/swiftui-backport-adoption/assets/backport-decision-record.md) and record:

1. Readiness status for every required consumer input, lifecycle status, native API, availability, consumer deployment targets, and supported platforms.
2. Selected semantic category and rejected alternatives.
3. Native and fallback behavior, including semantic deltas.
4. Correctness, accessibility, security, data-integrity, interaction, and layout risk.
5. Platform/OS validation matrix and unexecutable gaps.
6. Compiler lifecycle for each declaration or surface and platform: verified `deprecated`, optional `obsoleted`, and replacement message, or a no-replacement or platform-scoped exception reason.
7. For a retained-type exception, the unannotated `Backported` type, its independent product value and evidence, every compatibility-only surface to deprecate, its owner, and a product review/removal trigger independent of native availability.
8. Owner, decision date, removal trigger, and target release for any deferral.

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

## 6. Compiler-Enforced Lifecycle

Apply lifecycle rules declaration by declaration and surface by surface. By
default, every consumer-owned declaration whose compatibility purpose ends at
verified native availability receives platform-specific `deprecated` at that
availability, with a message naming the replacement and removal condition.

The sole retained-type exception is a `Backported` type with documented product
value independent of compatibility. That type may remain unannotated only when
the decision record names the retained value, supporting evidence, owner, and
an independent product review/removal trigger. Compatibility-only modifiers,
native conversions, bridges, compatibility initializers, and similar surfaces
still receive lifecycle annotations when the compiler can express them. This
exception does not apply to ordinary backport types or modifiers.

For every other supported platform or surface, record either that no native
replacement exists or a platform-scoped reason why the consumer compiler or
toolchain cannot express the intended lifecycle. Do not use unconditional
`@available(*, deprecated, ...)` while an older supported target still needs
the fallback.

`obsoleted` is optional: use it only for a platform-specific declaration or
when every supported platform shares an aligned removal threshold. Otherwise,
it can reject a shared call site on one platform while another still requires
the backport. See [Deprecating your own convenience API](https://swiftwithmajid.com/2026/05/19/deprecating-your-own-convenience-api/)
for the compiler-reminder pattern.

## 7. Verification Gate

Every independently removable compatibility decision requires:

1. Ordinary compatibility-layer and unified-call-site type-checking for every supported platform.
2. For a retained-type exception, ordinary construction, storage, and product use at and above native availability without a type-level deprecation diagnostic.
3. Below-`deprecated`, at-`deprecated`, and at-`obsoleted` checks when present, for every annotated compatibility-only surface on platforms with verified lifecycle annotations.
4. A recorded no-replacement or platform-scoped lifecycle-exception reason for every other supported platform or surface.
5. Confirmation that platform-specific lifecycle annotations do not reject a shared call site on a platform that still requires it.
6. Compile coverage for native and fallback branches.
7. At least one fallback behavior assertion or the strongest feasible proxy.
8. At least one native behavior assertion when the native runtime is available.
9. Source-stability coverage for the unified `.backport.` or `Backported.` call site.
10. A platform/OS matrix that records `native`, `fallback`, both, or unexecuted for each supported platform.
11. Explicit proxy evidence and confidence limits for branches CI cannot execute.

Compiler diagnostics and compilation prove only type and availability
correctness. They do not prove visual, interaction, accessibility, or data
behavior.

## 8. Upgrade and Removal

A deprecation warning after a deployment-target increase starts the removal
workflow; it does not authorize deletion. Delete a shared compatibility slice
only after every supported target reaches the native API's availability:

1. Replace backport call sites with the native API while preserving behavior.
2. Remove obsolete modifiers, native conversions, bridges, compatibility initializers, fallbacks, and legacy helpers at their recorded triggers.
3. Remove obsolete tests and documentation; retain native behavior coverage.
4. Keep only an independently valuable `Backported` type, plus its product-owned tests and documentation, when the retained-type exception is documented and still supported by evidence.
5. Re-review or remove the retained type only at its separate product trigger; do not tie that trigger to native availability.
6. Remove the package dependency only after repository-wide searches prove no other uses remain.
7. Close linked decision records independently with removal evidence, release, and validation matrices.

Complete compatibility-only surface removal in the first release cycle after
the deployment-target change. A retained type follows its independent product
trigger. Record a reason and target release for any deferral.

## 9. Anti-Patterns

1. Undocumented differences between native and fallback branches.
2. One wrapper API representing unrelated semantics.
3. No-op fallback for a required or accessibility-relevant outcome without neutrality evidence.
4. Compatibility helper with no owner or removal trigger.
5. Feature-level availability checks duplicated around a unified backport API.
6. Documentation examples that look executable but omit required types or conversions.
7. Leaving compatibility-only surfaces unannotated because their `Backported` type has independent product value.

## 10. References

- Dave DeLong, [Simplifying Backwards Compatibility in Swift](https://davedelong.com/blog/2021/10/09/simplifying-backwards-compatibility-in-swift/)
- SwiftUI Garden, [Handling different iOS versions in a View body](https://swiftui-garden.com/Articles/Handling-different-iOS-versions-in-a-View-body)
- Apple, [`View.badge(_:)`](https://developer.apple.com/documentation/swiftui/view/badge(_:)-8adyq)
