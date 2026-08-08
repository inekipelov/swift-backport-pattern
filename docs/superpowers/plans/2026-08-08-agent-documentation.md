# Agent-Ready Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a verified, cross-agent documentation system that gives developers and AI agents truthful examples, stable backport rules, and an on-demand adoption workflow.

**Architecture:** Keep public knowledge in README and `docs/`, durable repository rules in `AGENTS.md`, and the repeatable workflow in one canonical `.agents/skills/backport-adoption` folder. Bridge Claude Code to the same skill and enforce the structure with a dependency-free contract script plus compiled Swift examples.

**Tech Stack:** Swift 5.0 package, XCTest, POSIX shell, Markdown, Agent Skills `SKILL.md`.

## Global Constraints

- Preserve the existing public Swift API, dependencies, deployment targets, and `swift-tools-version: 5.0`.
- Preserve and refine the user's uncommitted compact adoption-guide work; do not replace it with the previous long version.
- Use semantic category identifiers instead of section numbers.
- Keep every README example compilable and label illustrative guide snippets explicitly.
- Keep one canonical skill under `.agents/skills/backport-adoption`.
- Do not add `opencode.json`, `.codex/config.toml`, DocC, runtime dependencies, commits, or pushes.

---

### Task 1: Documentation contract

**Files:**
- Create: `scripts/validate-documentation.sh`
- Modify: `.github/workflows/test.yml`

**Interfaces:**
- Produces: `scripts/validate-documentation.sh`, a zero-argument command that exits nonzero and prints one concise diagnostic for each violated repository-documentation contract.
- Consumes: the file layout and exact stable identifiers defined by the design spec.

- [x] **Step 1: Add the failing contract script**

Create checks for the future files and current known defects:

```sh
require_file AGENTS.md
require_file CLAUDE.md
require_file docs/README.md
require_file docs/AI_AGENT_ADOPTION.md
require_file .agents/skills/backport-adoption/SKILL.md
require_text docs/BACKPORT_ADOPTION_GUIDE.md 'redirect-fallback'
reject_text README.md 'AGENT-DOC:'
reject_text README.md 'modernFeature()'
reject_text README.md 'modernModifier()'
```

- [x] **Step 2: Run the contract and verify RED**

Run: `sh scripts/validate-documentation.sh`

Expected: nonzero exit with missing `AGENTS.md` as the first diagnostic.

- [x] **Step 3: Wire the contract into CI**

Add this step before `swift test -v` in `.github/workflows/test.yml`:

```yaml
- name: Validate documentation contract
  run: sh scripts/validate-documentation.sh
```

### Task 2: Durable instructions and public documentation

**Files:**
- Create: `AGENTS.md`
- Create: `CLAUDE.md`
- Create: `docs/README.md`
- Create: `docs/AI_AGENT_ADOPTION.md`
- Modify: `docs/BACKPORT_ADOPTION_GUIDE.md`

**Interfaces:**
- Produces: one repository instruction contract, one documentation map, stable category names, and consumer skill-installation guidance.
- Consumes: `scripts/validate-documentation.sh` from Task 1.

- [x] **Step 1: Add concise repository instructions**

`AGENTS.md` must state purpose, source precedence, routing, commands, documentation rules, and scope boundaries. `CLAUDE.md` must contain exactly:

```md
@AGENTS.md
```

- [x] **Step 2: Repair the adoption guide**

Rename numbered category references to the four semantic identifiers. Replace incomplete code blocks with brief category contracts and point to `Tests/DocumentationExamples.swift` for compiled examples. Link the reusable decision-record asset.

- [x] **Step 3: Add documentation navigation and consumer setup**

`docs/README.md` must map audience and source of truth. `docs/AI_AGENT_ADOPTION.md` must distinguish repository-maintainer discovery from consumer-repository installation and cover Codex, OpenCode, and Claude Code without duplicating skill content.

- [x] **Step 4: Run the contract**

Run: `sh scripts/validate-documentation.sh`

Expected: still FAIL because the skill and README cleanup are not complete; all Task 2 file checks pass.

### Task 3: Compiled examples and truthful README

**Files:**
- Create: `Tests/DocumentationExamples.swift`
- Modify: `README.md`

**Interfaces:**
- Produces: compiled examples for wrapper initialization, a constrained value-type extension, and a SwiftUI extension when SwiftUI is available.
- Consumes: `Backport`, `Backported`, and existing XCTest configuration.

- [x] **Step 1: Add compile-first documentation examples**

Add an XCTest file with a local value type and constrained extension:

```swift
private struct DocumentationValue {
    let title: String
}

private extension Backport where Content == DocumentationValue {
    var normalizedTitle: String {
        content.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
```

Assert the exact normalized result and compile a SwiftUI `eraseToAnyView()` example behind `#if canImport(SwiftUI)`.

- [x] **Step 2: Run the focused test and verify GREEN**

Run: `swift test --filter DocumentationExamplesTests`

Expected: all documentation-example tests pass.

- [x] **Step 3: Replace fictitious README usage**

Use the same constrained-extension example and explicitly state that consumers define concrete backports in their own modules. Remove `AGENT-DOC` and link `docs/README.md`, the adoption guide, and agent adoption guide.

### Task 4: Cross-agent adoption skill

**Files:**
- Create: `.agents/skills/backport-adoption/SKILL.md`
- Create: `.agents/skills/backport-adoption/agents/openai.yaml`
- Create: `.agents/skills/backport-adoption/assets/backport-decision-record.md`
- Create: `.claude/skills/backport-adoption` as a symlink to `../../.agents/skills/backport-adoption`

**Interfaces:**
- Produces: skill name `backport-adoption` and a copy-ready decision-record asset.
- Consumes: `docs/BACKPORT_ADOPTION_GUIDE.md`, the consumer repository's deployment targets, and primary Apple API documentation.

- [x] **Step 1: Record baseline skill scenarios**

Use fresh agents without the skill for creation, unsafe no-op review, and removal scenarios. Record omissions involving discovery, stable categories, decision-record shape, or verification/removal evidence.

- [x] **Step 2: Initialize a temporary scaffold**

Run `init_skill.py backport-adoption` under a temporary directory with `assets` and generated interface values. Copy no placeholders into the repository.

- [x] **Step 3: Write the minimal skill and asset**

Use trigger-only frontmatter beginning with `Use when`. The body must route to the canonical guide, define the create/review/remove workflow, and require a decision record with these exact sections:

```md
## Context
## Category
## Behavior Contract
## Risk
## Platform Matrix
## Verification
## Ownership and Removal
```

- [x] **Step 4: Create the Claude bridge**

Create `.claude/skills/backport-adoption` as a relative symlink to the canonical `.agents` skill. Do not duplicate `SKILL.md`.

- [x] **Step 5: Validate skill structure and contract**

Run:

```sh
python3 /Users/inekipelov/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/backport-adoption
sh scripts/validate-documentation.sh
```

Expected: both commands pass.

- [x] **Step 6: Run skill GREEN scenarios**

Repeat the three baseline scenarios with the skill explicitly supplied. Verify category selection, decision-record completeness, unsafe no-op rejection, and removal evidence.

### Task 5: Final verification

**Files:**
- Inspect: all changed files

**Interfaces:**
- Consumes: every deliverable from Tasks 1-4.
- Produces: verified working-tree handoff without commit or push.

- [x] **Step 1: Run narrow checks**

```sh
sh scripts/validate-documentation.sh
swift test --filter DocumentationExamplesTests
```

- [x] **Step 2: Run full checks**

```sh
swift test
swift build
git diff --check
```

- [x] **Step 3: Inspect scope**

Run `git status --short`, `git diff --stat`, and `git diff`. Confirm there are no runtime API, dependency, package-manifest, or unrelated changes.
