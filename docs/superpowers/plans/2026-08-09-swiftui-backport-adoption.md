# SwiftUI Backport Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the vendored SwiftUI backport skill a self-contained consumer-agent workflow with readiness, migration, and compiler-enforced deprecation lifecycle guidance.

**Architecture:** Keep procedural requirements in the copied skill directory, examples in its reference, and the reusable decision artifact in its asset. Keep `AI_AGENT_ADOPTION.md` installation-focused and make the adoption guide a human explanation of the canonical skill workflow rather than a competing instruction source.

**Tech Stack:** Markdown, Codex skill YAML frontmatter, Swift `@available` declarations, SwiftPM repository contract tests.

## Global Constraints

- Do not add concrete backport APIs or compatibility types to `Sources/` or `Tests/`.
- Preserve `swift-tools-version: 5.0`, deployment targets, the package public API, and the four semantic category identifiers.
- Use one category per compatibility decision; allow linked decisions for composite features.
- Require platform-specific `deprecated` annotations when a native replacement exists and the consumer compiler can express the lifecycle.
- Keep `obsoleted` conditional so a shared API is not rejected while another supported platform still needs it.
- Do not add brittle tests that assert documentation wording.
- Do not commit or push without a separate explicit user request.

---

### Task 1: Make the vendored skill workflow self-contained

**Files:**
- Modify: `.agents/skills/swiftui-backport-adoption/SKILL.md`
- Modify: `.agents/skills/swiftui-backport-adoption/assets/backport-decision-record.md`
- Modify: `.agents/skills/swiftui-backport-adoption/agents/openai.yaml`

**Interfaces:**
- Consumes: consumer repository rules, deployment targets, platform matrix, Apple API availability, product semantics, verification commands, ownership, and release policy.
- Produces: a readiness verdict; one category per compatibility decision; a persisted decision record; platform-specific lifecycle annotations; verification gaps; removal trigger.

- [ ] **Step 1: Replace the partial context check with a readiness gate**

Require these inputs to be marked `Discovered`, `Confirmed`, or `Missing`: repository/module, targets/platforms, native declaration, behavior/deltas, call sites, verification commands, owner, decision-record convention, and removal release. State that missing semantic, ownership, verification, or lifecycle inputs block implementation but still produce a `Blocked` handoff.

- [ ] **Step 2: Define decision granularity and persistence**

State that exactly one category is selected per independently removable compatibility decision. Add linked-decision handling for a `Backported` type plus its consuming modifier. Resolve the record path from repository instructions, then an existing ADR/decision convention, then `docs/backports/<api-name>.md` when permitted.

- [ ] **Step 3: Add compiler-enforced lifecycle rules**

Require platform-specific `deprecated` versions equal to native availability, a message naming the native replacement and removal condition, and a recorded exception when the compiler cannot express the lifecycle. Forbid unconditional `@available(*, deprecated, ...)` for APIs still needed below the native floor. Allow `obsoleted` only for platform-specific declarations or aligned cross-platform removal thresholds.

- [ ] **Step 4: Add an explicit migration workflow**

Inventory distributed availability branches and helpers, record current semantics, create compatibility decisions, introduce the unified namespace without semantic changes, migrate call sites, search for remnants, and remove replaced helpers only after verification.

- [ ] **Step 5: Extend verification and removal gates**

Require type-check evidence below and at `deprecated`, plus at `obsoleted` when present. Preserve the distinction between compiler diagnostics and behavior evidence. Treat a deprecation warning after a target increase as a removal signal, then require all supported targets to reach native availability before deleting a shared compatibility slice.

- [ ] **Step 6: Expand the decision-record asset**

Add a client-readiness table, a linked-decisions field, and this lifecycle table:

```markdown
| Platform | Native since | Deprecated | Obsoleted or omitted | Replacement and message | Evidence or exception |
| --- | --- | --- | --- | --- | --- |
```

Keep the existing behavior, risk, platform, verification, ownership, and removal sections.

- [ ] **Step 7: Synchronize UI metadata**

Update `agents/openai.yaml` so `short_description` and `default_prompt` cover creating, reviewing, migrating, and removing SwiftUI compatibility APIs.

- [ ] **Step 8: Run the narrow skill-structure check**

Run:

```sh
swift test --filter RepositoryStructureTests.testSwiftUIBackportSkillFrontmatterMatchesItsDirectory
```

Expected: the frontmatter contains only `name` and `description`, the name matches the directory, and the description is nonempty.

---

### Task 2: Add a concise real-world lifecycle reference

**Files:**
- Modify: `.agents/skills/swiftui-backport-adoption/references/category-examples.md`

**Interfaces:**
- Consumes: the skill's compiler-lifecycle requirements and the existing consumer-owned SwiftUI examples.
- Produces: an adaptable platform-specific `@available` example plus multi-platform safety guidance.

- [ ] **Step 1: Add a lifecycle section to the reference contents**

Place `Compiler-enforced lifecycle` before the category examples so an agent can load it when defining a decision.

- [ ] **Step 2: Add an annotated consumer backport example**

Use a reduced existing SwiftUI modifier declaration and show separate annotations such as:

```swift
@available(iOS, deprecated: 26.0, message: "Replace .backport.backgroundExtensionEffect() with native .backgroundExtensionEffect() after all minimum targets support it.")
@available(macOS, deprecated: 26.0, message: "Replace .backport.backgroundExtensionEffect() with native .backgroundExtensionEffect() after all minimum targets support it.")
func backgroundExtensionEffect() -> some View
```

Explain that deployment targets below 26 do not warn, targets at 26 warn, and `obsoleted` is intentionally omitted when per-platform target movement could make a still-needed shared call site unavailable.

- [ ] **Step 3: Keep the example contract explicit**

Label the snippet as consumer reference code, require the consumer to verify exact SDK availability, and state that compiler diagnostics do not prove native or fallback behavior.

- [ ] **Step 4: Verify relative links after the reference change**

Run:

```sh
swift test --filter RepositoryStructureTests.testRelativeMarkdownLinksResolve
```

Expected: all local Markdown links resolve.

---

### Task 3: Align installation, human guidance, and repository routing

**Files:**
- Modify: `docs/AI_AGENT_ADOPTION.md`
- Modify: `docs/BACKPORT_ADOPTION_GUIDE.md`
- Modify: `AGENTS.md`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- Consumes: the canonical self-contained skill workflow from Task 1.
- Produces: installation guidance that supplies the readiness inputs and human documentation that points to, but does not override, the agent workflow.

- [ ] **Step 1: Complete required consumer context**

In `AI_AGENT_ADOPTION.md`, add repository/module ownership, decision-record convention, named owner, planned removal release, compiler/toolchain availability, and warning policy. Explain that material missing inputs produce a blocked decision handoff rather than speculative implementation.

- [ ] **Step 2: Explain compiler-enforced lifecycle to developers**

In `BACKPORT_ADOPTION_GUIDE.md`, add a concise lifecycle section after implementation rules. Require platform-specific `deprecated` at native availability, make `obsoleted` conditional, explain the cross-platform hazard, and link to [Deprecating your own convenience API](https://swiftwithmajid.com/2026/05/19/deprecating-your-own-convenience-api/).

- [ ] **Step 3: Align decision, verification, and removal sections**

Add readiness status and compiler lifecycle to the mandatory decision record. Add below/at/obsoleted diagnostic checks to verification without calling them behavior coverage. State that warnings initiate the removal workflow but all supported targets still gate deletion.

- [ ] **Step 4: Make source ownership unambiguous**

Update `AGENTS.md` and `CONTRIBUTING.md` so the copied skill owns the normative repeatable agent workflow while the adoption guide owns human-readable rationale and examples. Keep contribution, release, package API, and test ownership unchanged.

- [ ] **Step 5: Run repository contract checks**

Run:

```sh
swift test --filter RepositoryStructureTests
git diff --check
```

Expected: canonical paths, Claude bridge, skill frontmatter, and Markdown links pass; the diff has no whitespace errors.

---

### Task 4: Validate semantics and final scope

**Files:**
- Verify only: all modified files and the approved design/plan artifacts.

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: compiler evidence, isolated skill forward-test results, full package verification, and a scoped final diff.

- [ ] **Step 1: Verify compiler lifecycle behavior**

Type-check an analogous iOS declaration with a writable module cache:

```sh
xcrun --sdk iphoneos swiftc -module-cache-path /private/tmp/swift-backport-pattern-module-cache -typecheck -target arm64-apple-ios14.0 -e '@available(iOS, deprecated: 15, obsoleted: 16, message: "Use native API") func compatibilityAPI() {}; compatibilityAPI()'
xcrun --sdk iphoneos swiftc -module-cache-path /private/tmp/swift-backport-pattern-module-cache -typecheck -target arm64-apple-ios15.0 -e '@available(iOS, deprecated: 15, obsoleted: 16, message: "Use native API") func compatibilityAPI() {}; compatibilityAPI()'
xcrun --sdk iphoneos swiftc -module-cache-path /private/tmp/swift-backport-pattern-module-cache -typecheck -target arm64-apple-ios16.0 -e '@available(iOS, deprecated: 15, obsoleted: 16, message: "Use native API") func compatibilityAPI() {}; compatibilityAPI()'
```

Expected: no diagnostic at iOS 14, a deprecation warning at iOS 15, and an unavailable error at iOS 16.

- [ ] **Step 2: Forward-test the skill in isolated consumer scenarios**

Run fresh-agent evaluations for: safe `View.badge(_:)` no-op; a linked compatibility type and modifier; migration from distributed `#available`; and rejection of an accessibility-breaking no-op. Each output must include readiness, ownership, category per decision, rejected alternatives, lifecycle annotations or exceptions, platform evidence, and removal ownership without invented consumer facts.

- [ ] **Step 3: Run full package verification**

Run:

```sh
swift test
swift build
git diff --check
```

Expected: all repository tests and the build pass, with no whitespace errors.

- [ ] **Step 4: Inspect final scope**

Run:

```sh
git status --short
git diff --stat
git diff -- . ':!docs/superpowers/specs/2026-08-09-swiftui-backport-adoption-design.md' ':!docs/superpowers/plans/2026-08-09-swiftui-backport-adoption.md'
```

Expected: only the canonical skill, its bundled resources/metadata, aligned repository guidance, and the approved design/plan artifacts are changed; no package source or package test file is modified.
