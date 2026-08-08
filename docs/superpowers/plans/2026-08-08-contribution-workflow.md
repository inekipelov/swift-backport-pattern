# Contribution Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an executable, shared contribution workflow for external contributors, maintainers, and AI agents.

**Architecture:** Put the complete contribution lifecycle in root `CONTRIBUTING.md`, keep repository constraints in `AGENTS.md`, and leave backport semantics in the adoption guide and project skill. Link these sources through the public documentation map and enforce their required structure with the existing POSIX shell documentation validator.

**Tech Stack:** Markdown, POSIX shell, Swift Package Manager, XCTest, GitHub Actions, gitlint.

## Global Constraints

- Preserve `swift-tools-version: 5.0`, deployment targets, dependencies, and the public Swift API.
- Keep one tool-neutral contribution contract; do not add Codex-, Claude-, or OpenCode-specific copies.
- Require a short-lived branch and pull request for every change.
- Require green Build, Test, and Gitlint checks, resolved review threads, and independent human approval before every merge.
- Keep issue creation optional and recommend prior discussion only for ambiguous or high-risk work.
- Do not add templates, `CODEOWNERS`, branch-protection configuration, release automation, or runtime code.
- Do not commit, push, publish, or merge without explicit human authorization.

---

### Task 1: Make the contribution contract executable

**Files:**
- Modify: `scripts/validate-documentation.sh`

**Interfaces:**
- Consumes: the existing `require_file` and `require_text` shell helpers.
- Produces: structural validation for the canonical contribution document and all three navigation entry points.

- [x] **Step 1: Add the missing-file assertion first**

Add this assertion beside the other required root files:

```sh
require_file CONTRIBUTING.md
```

- [x] **Step 2: Run the validator and verify RED**

Run:

```sh
sh scripts/validate-documentation.sh
```

Expected: nonzero exit with `documentation contract: missing required file: CONTRIBUTING.md`.

- [x] **Step 3: Add exact structural checks**

Require the following stable text after the existing README and guide checks:

```sh
require_text CONTRIBUTING.md '## Sources of Truth'
require_text CONTRIBUTING.md '## Branch Workflow'
require_text CONTRIBUTING.md '## Risk Classification'
require_text CONTRIBUTING.md '## Backport-Specific Changes'
require_text CONTRIBUTING.md '## Verification'
require_text CONTRIBUTING.md '## AI-Assisted Contributions'
require_text CONTRIBUTING.md '## Review, Merge, and Definition of Done'
require_text CONTRIBUTING.md 'sh scripts/validate-documentation.sh'
require_text CONTRIBUTING.md 'swift test'
require_text CONTRIBUTING.md 'swift build'
require_text CONTRIBUTING.md 'git diff --check'
require_text CONTRIBUTING.md 'independent human approval'
require_text README.md '[Contributing](CONTRIBUTING.md)'
require_text docs/README.md '[Contribution Workflow](../CONTRIBUTING.md)'
require_text AGENTS.md '`CONTRIBUTING.md` owns the contribution workflow'
```

Keep the checks exact and dependency-free. They enforce durable identifiers and
routing rather than attempting natural-language policy analysis.

### Task 2: Add the shared contribution workflow

**Files:**
- Create: `CONTRIBUTING.md`

**Interfaces:**
- Consumes: repository constraints from `AGENTS.md`, backport policy from `docs/BACKPORT_ADOPTION_GUIDE.md`, the project skill, `.gitlint`, and the baseline verification commands.
- Produces: one public workflow for contributors, maintainers, and AI agents.

- [x] **Step 1: Add the canonical section structure**

Create these sections in this order:

```md
# Contributing
## Purpose and Audience
## Sources of Truth
## Development Setup
## Choosing and Scoping Work
## Branch Workflow
## Risk Classification
## Implementation Rules
## Backport-Specific Changes
## Verification
## Commits and Pull Requests
## AI-Assisted Contributions
## Review, Merge, and Definition of Done
```

- [x] **Step 2: Define work selection and risk**

State that issues are optional, discussion is recommended for ambiguous or
high-risk work, and unrelated changes belong in separate pull requests. Define
trivial, standard, and high-risk changes using the exact boundaries in the
design spec. Require explicit maintainer agreement before a high-risk public
contract is changed.

- [x] **Step 3: Define branch, commit, and pull request flow**

Document synchronization of `main`, the `feature/`, `fix/`, `docs/`, `test/`,
and `chore/` prefixes, Draft-first pull requests, self-review, and Conventional
Commit titles accepted by `.gitlint`. Prohibit direct `main` commits,
force-pushing shared branches, and mixed-scope pull requests.

- [x] **Step 4: Define verification and failure reporting**

Include the exact baseline block:

```sh
sh scripts/validate-documentation.sh
swift test
swift build
git diff --check
```

Require regression coverage for behavior changes, compatibility assessment for
public API changes, and compiled or clearly illustrative documentation code.
For an unavailable check, require the exact command, blocker, unverified area,
and confidence boundary.

- [x] **Step 5: Define backport and AI boundaries**

Route backport work to the adoption guide and `backport-adoption` skill. Require
native and fallback evidence and a decision record. Require agents to read both
root contracts, preserve human changes, disclose material AI assistance, and
obtain explicit human authorization for commit, push, publish, or merge.

- [x] **Step 6: Define the merge gate**

Require successful GitHub Build, Test, and Gitlint checks, resolved actionable
threads, and independent human approval for every pull request. State that AI
review is supplementary evidence only. Prefer squash merge followed by branch
deletion.

- [x] **Step 7: Run the validator and inspect remaining failures**

Run:

```sh
sh scripts/validate-documentation.sh
```

Expected: `CONTRIBUTING.md` structure checks pass; navigation checks still fail
until Task 3.

### Task 3: Route humans and agents to the contract

**Files:**
- Modify: `README.md`
- Modify: `docs/README.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: root `CONTRIBUTING.md` from Task 2.
- Produces: public navigation and unambiguous source ownership for agent routing.

- [x] **Step 1: Link the package README**

Add this item to `README.md` under `## Documentation`:

```md
- [Contributing](CONTRIBUTING.md)
```

- [x] **Step 2: Link the documentation map**

Add this row to the `docs/README.md` Start Here table:

```md
| Contribute code, tests, or documentation | [Contribution Workflow](../CONTRIBUTING.md) |
```

Add `CONTRIBUTING.md` to Source Precedence as the owner of branch, review, and
merge workflow. Preserve the existing precedence of runtime sources and
backport policy.

- [x] **Step 3: Add agent routing without policy duplication**

Add this exact sentence under `AGENTS.md` Sources of Truth:

```md
`CONTRIBUTING.md` owns the contribution workflow, including branches, pull requests, review, and merge requirements.
```

Under Task Routing, direct all contributors and agents to read
`CONTRIBUTING.md` before changing the repository. Do not restate its detailed
workflow in `AGENTS.md`.

- [x] **Step 4: Run the contract**

Run:

```sh
sh scripts/validate-documentation.sh
```

Expected: `documentation contract: OK`.

### Task 4: Verify scope and repository health

**Files:**
- Inspect: `CONTRIBUTING.md`, `README.md`, `docs/README.md`, `AGENTS.md`, and `scripts/validate-documentation.sh`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: a verified documentation-only handoff with no runtime or public API change.

- [x] **Step 1: Run the baseline checks**

Run each command and observe exit status zero:

```sh
sh scripts/validate-documentation.sh
swift test
swift build
git diff --check
```

- [x] **Step 2: Audit Markdown links and prohibited additions**

Use repository-wide search to confirm every relative Markdown link resolves and
that no pull request template, issue template, `CODEOWNERS`, branch-protection
configuration, dependency, or Swift source change was added.

- [x] **Step 3: Inspect final scope**

Run:

```sh
git status --short
git diff --stat
git diff -- CONTRIBUTING.md README.md docs/README.md AGENTS.md scripts/validate-documentation.sh
```

Confirm the implementation touches only the five approved files in addition to
the design and implementation records, and that it contains no unrelated edits.
