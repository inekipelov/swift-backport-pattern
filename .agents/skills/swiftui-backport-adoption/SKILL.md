---
name: swiftui-backport-adoption
description: Use when creating, reviewing, migrating, or removing a SwiftUI compatibility API that uses Backport, Backported, availability checks, fallback behavior, polyfills, or OS-version bridging.
---

# SwiftUI Backport Adoption

## Core Principle

Preserve one stable call site while making every native/fallback semantic difference explicit, owned, tested, and removable.

## Confirm Repository Ownership

1. Identify the consumer repository and module that own the concrete compatibility API.
2. Continue concrete design or implementation only with product and platform context.
3. In `swift-backport-pattern`, limit work to the namespace mechanism, documentation, or synthetic tests. Do not add concrete compatibility APIs.
4. If concrete work targets the pattern package, return a `Blocked` handoff that requests the consumer repository.

## Readiness Gate

Read consumer instructions and mark each input `Discovered`, `Confirmed`, or `Missing` before selecting a category:

| Input | Status | Evidence or gap |
| --- | --- | --- |
| Repository and owning module | | |
| Deployment targets and supported platforms | | |
| Native declaration and availability | | |
| Required behavior and native/fallback deltas | | |
| Affected call sites and helpers | | |
| Verification commands and supported runtimes | | |
| Named owner | | |
| Decision-record convention | | |
| Planned removal release | | |

Missing semantic, ownership, verification, or lifecycle inputs block implementation. Still produce a `Blocked` handoff with the table, the exact missing input, the safe next action, and any verified facts.

Verify native signatures and availability with Apple documentation or installed SDK declarations. Read `docs/BACKPORT_ADOPTION_GUIDE.md` when the consumer provides it; consumer rules take precedence.

## Select and Persist a Decision

Read [references/category-examples.md](references/category-examples.md) before selecting. Choose exactly one category for each independently removable compatibility decision:

| Category | Observable condition |
| --- | --- |
| `redirect-fallback` | A legacy API preserves required outcomes with bounded, documented deltas. |
| `compatibility-type` | A native parameter or result type is unavailable on older targets. |
| `behavioral-polyfill` | Required behavior needs a custom legacy implementation. |
| `no-op-fallback` | The API is progressive enhancement and unchanged legacy behavior is proven safe. |

Do not use `no-op-fallback` when correctness, accessibility, security, data integrity, required interaction, or required layout can change. A `Backported` type and its consuming modifier are linked decisions when each can be removed independently: give each its own category and record, cross-link them, and document their different removal triggers.

Resolve the decision-record path in this order: repository instructions; an existing ADR or decision-record convention; then `docs/backports/<api-name>.md` when that new path is permitted. Copy [assets/backport-decision-record.md](assets/backport-decision-record.md), set its status, and complete every section before implementation, including rejected categories.

## Implement and Annotate Lifecycle

- Put instance APIs in constrained `extension Backport where Content: ...` declarations and compatibility types under `Backported`.
- Keep availability and platform branching inside the compatibility layer; keep concrete APIs in consumer modules.
- Make every fallback delta and unavailable platform explicit. Block ungrounded parity, unsafe no-ops, and missing platform branches.
- Decide lifecycle declaration by declaration and surface by surface. By default, each declaration whose compatibility purpose ends at verified native availability receives platform-specific `deprecated` equal to that availability and a message naming the replacement and removal condition.
- Keep a `Backported` type itself unannotated only when the decision record proves product value independent of compatibility. Name the retained value and evidence, every compatibility-only surface, the owner, and a review/removal trigger independent of the native-availability trigger.
- For a retained unannotated type, still annotate every compatibility-only modifier, native conversion, bridge, compatibility initializer, and similar surface when the compiler can express the lifecycle. The exception applies only to the independently valuable type declaration, not to ordinary backport types, modifiers, or other compatibility-only surfaces.
- For every other supported platform, record either that no native replacement exists or a platform-scoped reason why the compiler cannot express the intended lifecycle.
- Do not use unconditional `@available(*, deprecated, ...)` for an API still needed below its native floor.
- Use `obsoleted` only on platform-specific declarations, or when all platforms share an aligned removal threshold.

## Migrate Existing Availability Logic

1. Inventory distributed `#available` branches, compatibility helpers, call sites, tests, and docs.
2. Record current semantics and platform deltas before changing code.
3. Create one decision record per compatibility decision, including linked decisions.
4. Introduce the unified `Backport` or `Backported` namespace without semantic changes.
5. Migrate call sites to the unified API.
6. Search for remaining branches and helpers.
7. Remove replaced helpers only after verification proves the replacement preserves the recorded contract.

## Verify Evidence

Type-check the compatibility layer and unified call site in an ordinary supported configuration for every platform. For a retained unannotated `Backported` type, also cover ordinary construction, storage, and product use at and above native availability without a type-level deprecation diagnostic. Lifecycle threshold checks apply declaration by declaration to annotated surfaces on supported platforms: type-check below `deprecated`, at `deprecated`, and at `obsoleted` when present. For every other supported platform or surface, retain ordinary type-check coverage and record its no-replacement or lifecycle-exception reason. Record compiler diagnostics separately from behavior evidence.

Then:

1. Execute fallback behavior or record the strongest proxy and limit.
2. Execute native behavior where the runtime is available.
3. Cover the unified `.backport.` or `Backported.` call site.
4. Record `native`, `fallback`, both, or unexecuted in the platform matrix.

Compilation is not behavior, accessibility, visual, interaction, or data-integrity evidence.

## Remove a Backport

1. Treat a deprecation warning after a deployment-target increase as a removal signal.
2. Prove every supported target reaches native availability before deleting a shared compatibility slice.
3. Inventory the shim, call sites, types, bridges, helpers, tests, docs, and linked records.
4. Migrate call sites to the native API, then remove obsolete modifiers, native conversions, bridges, compatibility initializers, and replaced helpers at their recorded triggers.
5. Retain only the independently valuable `Backported` type and its product-owned tests and documentation. Re-review or remove that type only at its separate product trigger.
6. Close linked decision records independently with release and verification evidence.

## Output Contract

Return, in order: repository-ownership verdict; readiness table; category and linked decisions; behavior contract; rejected alternatives; risk; platform and lifecycle matrices; verification and gaps; owner and removal trigger. Lead reviews with blocking findings.

## Common Mistakes

- Using numeric section labels as category identifiers.
- Copying illustrative API names as if they exist.
- Hiding semantic deltas behind native-looking names.
- Treating a simulator compile as branch behavior evidence.
- Using a global deprecation that breaks supported fallback targets.
- Leaving compatibility-only surfaces unannotated because their `Backported` type has independent product value.
- Removing a shared slice after only one platform reaches the native floor.
