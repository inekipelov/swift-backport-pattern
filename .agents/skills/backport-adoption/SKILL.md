---
name: backport-adoption
description: Use when creating, reviewing, migrating, or removing a Swift or SwiftUI compatibility API that uses Backport, Backported, availability checks, fallback behavior, polyfills, or OS-version bridging.
---

# Backport Adoption

## Core Principle

Preserve one stable call site while making every native/fallback semantic difference explicit, owned, tested, and removable.

## Establish Context

1. Read `docs/BACKPORT_ADOPTION_GUIDE.md` when present.
2. Inspect consumer deployment targets, platforms, call sites, tests, and ownership.
3. Verify the native signature and availability using Apple documentation or SDK declarations.
4. Request missing product semantics when category selection would be speculative.

## Select One Category

| Category | Observable condition |
| --- | --- |
| `redirect-fallback` | A legacy API preserves required outcomes with bounded, documented deltas. |
| `compatibility-type` | A native parameter or result type is unavailable on older targets. |
| `behavioral-polyfill` | Required behavior needs a custom legacy implementation. |
| `no-op-fallback` | The API is progressive enhancement and unchanged legacy behavior is proven safe. |

Do not use `no-op-fallback` when correctness, accessibility, security, data integrity, required interaction, or required layout can change.

## Produce the Decision First

Copy [assets/backport-decision-record.md](assets/backport-decision-record.md) into the consumer's decision-record location. Set its lifecycle status and complete every section before implementation, including rejected categories.

## Implement or Review

- Put instance APIs in constrained `extension Backport where Content: ...` declarations.
- Put compatibility types under `Backported` and document invariants.
- Keep availability and platform branching inside the compatibility layer.
- Mirror native naming only when compatibility semantics justify it.
- Keep app-specific backports in consumer modules.
- Block ungrounded parity, unsafe no-ops, missing platform branches, and missing removal ownership.

## Verify Evidence

For each supported platform:

1. Compile native and fallback branches.
2. Execute fallback behavior or record the strongest proxy and limit.
3. Execute native behavior where the runtime is available.
4. Cover the unified `.backport.` or `Backported.` call site.
5. Record `native`, `fallback`, both, or unexecuted in the platform matrix.

Compilation is not behavior, accessibility, visual, interaction, or data-integrity evidence.

## Remove a Backport

1. Prove every minimum target reaches native availability.
2. Inventory the shim, call sites, types, bridges, helpers, tests, docs, and decision record.
3. Migrate call sites to the native API before deleting the compatibility slice.
4. Retain a compatibility type only when it has independent product value.
5. Remove the package dependency only after repository-wide searches prove no other usage remains.
6. Close the decision record with release and verification evidence.

## Output Contract

Return, in order: verdict or category; behavior contract; rejected alternatives; risk; platform matrix; verification and gaps; owner and removal trigger. Lead reviews with blocking findings.

## Common Mistakes

- Using numeric section labels as category identifiers.
- Copying illustrative API names as if they exist.
- Hiding semantic deltas behind native-looking names.
- Treating a simulator compile as branch behavior evidence.
- Removing a shared dependency after finding only one obsolete backport.
