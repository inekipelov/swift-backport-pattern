# SwiftUI Backport Adoption Skill Design

## Objective

Make `swiftui-backport-adoption` a self-contained execution instruction for an
AI agent working inside a consumer repository. Keep installation guidance and
human-oriented pattern explanation outside the skill.

The skill must make compatibility decisions explicit, prevent speculative
implementation, produce verifiable lifecycle artifacts, and make obsolete
backports visible to the Swift compiler.

## Responsibility Boundaries

The repository components have distinct responsibilities:

- `.agents/skills/swiftui-backport-adoption/SKILL.md` owns the executable agent
  workflow.
- `references/category-examples.md` owns concrete examples for the four
  compatibility categories.
- `assets/backport-decision-record.md` owns the decision-record template copied
  into consumer repositories.
- `docs/AI_AGENT_ADOPTION.md` owns skill installation and consumer-context
  preparation.
- `docs/BACKPORT_ADOPTION_GUIDE.md` explains the pattern to developers without
  defining a competing agent workflow.

Adding the Swift package dependency does not install the skill. Consumer
repositories vendor the complete skill directory and supply their build,
platform, architecture, and release rules through their own `AGENTS.md`.

## Client Readiness Gate

Before categorization or implementation, the agent resolves these inputs:

- consumer repository and owning module;
- minimum deployment targets and supported platforms;
- native Apple API signature and platform availability;
- required behavior and acceptable semantic differences;
- affected call sites;
- executable verification commands;
- compatibility owner;
- removal trigger and planned removal release.

Each input is classified as `Discovered`, `Confirmed`, or `Missing`. Missing
information that affects semantics, ownership, platform coverage, verification,
or removal blocks implementation. The agent still produces a decision handoff
with status `Blocked` and lists the exact missing inputs; it must not invent
consumer facts.

## Compatibility Decisions

The agent selects exactly one category per compatibility decision, not
necessarily one category per feature:

- `redirect-fallback`
- `compatibility-type`
- `behavioral-polyfill`
- `no-op-fallback`

A feature that requires an unavailable type and separate fallback behavior is
split into linked decisions. For example, a `Backported` value can be a
`compatibility-type`, while the modifier consuming it can independently be a
`behavioral-polyfill`.

Every decision records why the other categories were rejected. A no-op remains
forbidden when it can affect correctness, accessibility, security, data
integrity, required interaction, or required layout.

## Decision-Record Location

The agent selects a persistence location in this order:

1. A path explicitly defined by consumer repository instructions.
2. An existing ADR, decision, or backport-documentation convention.
3. `docs/backports/<api-name>.md` when the consumer has no applicable
   convention and repository rules do not prohibit a new documentation path.

The selected path is reported before writing. The agent must not create a
second decision-record system alongside an existing convention.

## Compiler-Enforced Lifecycle

Every consumer-owned backport records whether its lifecycle can be enforced
with platform-specific Swift availability annotations. A `deprecated` version
is required at creation time for every supported platform that has a native
replacement, unless the consumer's compiler cannot express the lifecycle. The
version equals the native API's availability on that platform:

```swift
@available(
    iOS,
    deprecated: 15,
    message: "Replace .backport.badge(_:) with native .badge(_:) after all minimum targets support it."
)
```

This follows the compiler-reminder technique described in
[Deprecating your own convenience API](https://swiftwithmajid.com/2026/05/19/deprecating-your-own-convenience-api/).
The annotation produces no warning while the deployment target remains below
the deprecation version and produces a warning after the target reaches it.

Rules:

- Use separate annotations for each supported platform with a native
  replacement.
- Do not use unconditional `@available(*, deprecated, ...)` for a compatibility
  API still required by older deployment targets.
- Name the native replacement and the removal condition in the message.
- Do not deprecate a `Backported` type that retains independent product value.
- Record a reason when compiler-enforced deprecation is not applicable.

An `obsoleted` version is optional. Use it only when the declaration is
platform-specific or when all supported platforms reach compatible removal
thresholds. Do not make a shared cross-platform API unavailable on one platform
while it remains necessary on another. When safe, `obsoleted` can enforce a
consumer-approved deadline after the warning phase:

```swift
@available(
    iOS,
    deprecated: 15,
    obsoleted: 16,
    message: "Use native .badge(_:)."
)
```

When `obsoleted` is unsafe or inconsistent with consumer release policy, omit
it and retain the deadline in the decision record.

## Migration Workflow

For an existing compatibility implementation, the agent:

1. Inventories scattered availability checks, platform branches, wrappers,
   types, call sites, tests, and documentation.
2. Records current native and fallback behavior before changing structure.
3. Creates one compatibility decision for each independently removable slice.
4. Introduces the unified `.backport` or `Backported` API without changing
   product semantics.
5. Migrates call sites incrementally.
6. Searches for remaining scattered branches and obsolete helpers.
7. Removes replaced code only after platform-specific verification passes.

Migration must not combine namespace adoption with an unapproved semantic
change.

## Verification

The existing behavior matrix remains mandatory for every supported platform.
Compiler lifecycle adds these checks:

1. Compile a representative unified call site with a deployment target below
   `deprecated`; expect no deprecation diagnostic.
2. Compile at the `deprecated` target; expect the intended warning and message.
3. When `obsoleted` is present, compile at that target; expect the call site to
   be rejected.
4. Confirm that platform-specific annotations do not reject a shared backport
   on a platform that still requires it.

Compile diagnostics do not establish fallback behavior, UI, interaction, or
accessibility parity. Runtime and product verification remain separate.

## Removal Workflow

A deprecation warning after a minimum-target increase is a signal to begin
removal, not proof that removal is safe. The agent must still:

1. Prove every supported platform has reached native availability.
2. Inventory the compatibility declaration, call sites, bridges, tests,
   documentation, and decision record.
3. Replace unified call sites with the native API.
4. Verify affected platforms and behavior.
5. Delete the compatibility slice and close its decision record.

Removal should complete in the first release cycle after all required minimum
targets reach native availability unless the consumer records an explicit
deferral.

## Metadata and Documentation Alignment

`agents/openai.yaml` must describe the full create, review, migrate, and remove
scope. `docs/AI_AGENT_ADOPTION.md` remains installation-focused and lists the
consumer context required by the readiness gate. The human adoption guide may
explain the same concepts but must point to the skill for the normative agent
workflow.

The vendored skill directory must remain usable when the package repository's
external `docs/` directory is absent.

## Validation Scenarios

Forward-test the revised skill with four isolated consumer scenarios:

1. `View.badge(_:)` using a safe `no-op-fallback`.
2. An unavailable SwiftUI type and a modifier requiring two linked decisions.
3. Migration of scattered `#available` branches into a unified `.backport`
   call site.
4. A proposed no-op that would lose required accessibility or interaction
   behavior and must be blocked.

For the lifecycle rule, type-check representative iOS declarations below, at,
and above their configured availability thresholds. A successful result must
show consistent ownership, no invented client context, correct decision
granularity, expected diagnostics, and safe handling of cross-platform APIs.

## Scope

The change updates only repository guidance, the canonical project skill, its
metadata, references, and decision-record asset. It does not add concrete
backport methods or compatibility types to the package public API.
