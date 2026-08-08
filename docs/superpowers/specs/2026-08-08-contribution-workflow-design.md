# Contribution Workflow Design

## Goal

Define one contribution contract for external contributors, maintainers, and AI
agents. The contract must make change scope, risk, verification, review, and merge
requirements explicit without duplicating the package's backport policy or
tool-specific agent instructions.

## Audience

`CONTRIBUTING.md` serves three audiences through the same workflow:

1. External contributors proposing changes to the package or documentation.
2. Maintainers reviewing and merging those changes.
3. AI coding agents assisting either group under explicit human authority.

The document uses English because it is a public repository entry point.

## Source Ownership

Each document owns one layer of the repository contract:

- `CONTRIBUTING.md`: contribution lifecycle from choosing work through merge.
- `AGENTS.md`: repository constraints, task routing, and verification commands.
- `docs/BACKPORT_ADOPTION_GUIDE.md`: backport semantics and lifecycle policy.
- `.agents/skills/backport-adoption/SKILL.md`: operational AI workflow for
  backport-specific work.
- `README.md` and `docs/README.md`: navigation to the canonical sources.

`CONTRIBUTING.md` links to the other sources instead of restating their detailed
rules. Codex, Claude Code, and OpenCode continue to share the same repository
contract; no tool-specific contribution document is added.

## Contribution Lifecycle

Every change uses a short-lived branch and a pull request. Direct changes to
`main` are not part of the supported workflow.

1. Synchronize local `main` with the remote.
2. Create a focused branch using `feature/`, `fix/`, `docs/`, `test/`, or
   `chore/`.
3. Keep one coherent change in the branch and separate unrelated work.
4. Classify the change as trivial, standard, or high-risk.
5. Implement the smallest sufficient change and run risk-proportionate checks.
6. Use a Conventional Commit title accepted by `.gitlint`.
7. Open a Draft pull request, disclose verification and material AI assistance,
   and self-review the diff.
8. Mark the pull request ready only after known failures and scope issues are
   resolved.
9. Merge only after required CI is green, review threads are resolved, and an
   independent human has approved the pull request.
10. Prefer squash merge and delete the short-lived branch after merge.

Opening an issue before a pull request is never mandatory. Discussion is
recommended when requirements are ambiguous or a change may affect a public
contract, compatibility, security, or long-term maintenance.

## Risk Classification

### Trivial

Non-executable text, comments, and isolated documentation corrections that do
not change a documented contract or code example.

### Standard

Backward-compatible code, tests, CI, executable documentation, and scoped
refactoring that preserves existing public behavior.

### High-risk

Changes to public API, compatibility, deployment targets, Swift tools version,
dependencies, availability or fallback semantics, security, privacy, or data
integrity.

High-risk work requires explicit maintainer agreement on the affected contract
before implementation proceeds. The contribution guide does not prescribe an
issue as the only place for that agreement.

## Engineering and Backport Rules

Contributors preserve existing architecture, naming, compatibility, and
unrelated user changes. New abstractions or dependencies require demonstrated
need.

Backport-specific work must use the adoption guide and `backport-adoption`
skill. It must record the category, native and fallback behavior, supported
platform evidence, risks, ownership, and removal trigger. Compilation alone is
not behavior evidence.

## Verification Contract

The repository baseline is:

```sh
sh scripts/validate-documentation.sh
swift test
swift build
git diff --check
```

Behavior changes require regression coverage. Public API changes require an
explicit compatibility assessment. Documentation code must compile through
`Tests/DocumentationExamples.swift` or be clearly labelled as illustrative
pseudocode.

When a relevant check cannot run, the pull request must name the exact command,
the blocker, the unverified behavior, and the resulting confidence boundary.
GitHub Build, Test, and Gitlint checks are required for merge.

## Pull Request, Review, and Merge Contract

A pull request describes the problem, the scoped solution, risk classification,
verification evidence, compatibility impact, and unresolved limitations. Failed
checks block readiness and merge. Unrelated changes are split into another pull
request.

Every pull request requires approval from an independent human reviewer. AI
review can add evidence but cannot satisfy that approval requirement. All
actionable review threads must be resolved before merge.

Force-pushing shared branches, mixing unrelated work, and committing directly
to `main` are prohibited. No branch-protection configuration is changed by this
documentation task; enforcement outside the repository remains a maintainer
responsibility.

## AI-Assisted Contributions

AI agents read `AGENTS.md` and `CONTRIBUTING.md` before modifying the repository
and load the project skill when backport semantics are involved. They preserve
human changes, keep scope explicit, and never fabricate verification evidence.

Pull requests disclose material AI creation or review and identify the human
verification performed. An AI agent may commit, push, publish, or merge only
with explicit human authorization. AI review never substitutes for independent
human approval.

## Executable Documentation Contract

`scripts/validate-documentation.sh` will require:

- the root `CONTRIBUTING.md` file;
- its canonical workflow, risk, verification, AI, and review headings;
- the four baseline verification commands;
- the independent human approval rule;
- navigation links from `README.md`, `docs/README.md`, and `AGENTS.md`.

These checks protect document structure and routing. They do not attempt to
prove the meaning of natural-language policy.

## Scope

This change creates `CONTRIBUTING.md` and updates `README.md`, `docs/README.md`,
`AGENTS.md`, and `scripts/validate-documentation.sh`.

It does not add pull request templates, issue templates, `CODEOWNERS`, branch
protection, release automation, dependencies, Swift source changes, or public
API changes.
