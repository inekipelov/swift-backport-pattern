# Contributing

## Purpose and Audience

This guide defines the contribution workflow for external contributors,
maintainers, and AI coding agents. Everyone follows the same scope,
verification, review, and merge requirements; tool-specific instructions do
not replace this contract.

Prefer the smallest change that completely solves the stated problem. Preserve
repository integrity, existing conventions, and backward compatibility unless
an approved change explicitly requires otherwise.

## Sources of Truth

Use each source for the responsibility it owns:

1. Public declarations under [`Sources/`](Sources/) and executable behavior
   under [`Tests/`](Tests/) define the package's current code contract.
2. This file defines how changes are scoped, developed, verified, reviewed, and
   merged.
3. The [`Release Guide`](docs/RELEASING.md) defines release authorization,
   SemVer calculation, publication, ordering, and recovery policy.
4. [`docs/BACKPORT_ADOPTION_GUIDE.md`](docs/BACKPORT_ADOPTION_GUIDE.md) defines
   backport selection, behavior, evidence, and lifecycle policy.
5. [`.agents/skills/swiftui-backport-adoption/SKILL.md`](.agents/skills/swiftui-backport-adoption/SKILL.md)
   defines the repeatable AI workflow for SwiftUI backport work.
6. [`AGENTS.md`](AGENTS.md) defines repository constraints and task routing.
7. [`README.md`](README.md) is the concise package entry point.

When two sources appear to conflict, follow the source that owns the affected
responsibility and call out the conflict in the pull request. Do not silently
choose a materially different public or compatibility contract.

## Repository Boundary

This repository owns the reusable `Backport`/`Backported` namespace mechanism,
its public access points, tests, documentation, and adoption workflow. Concrete
compatibility APIs must be implemented and owned by a consumer repository.

Do not add Apple API methods, compatibility types, fallback implementations,
or product-specific availability policy to this package's `Sources/`. A real
backport requires the consumer's deployment targets, supported platforms,
product semantics, call sites, tests, release policy, owner, and removal
trigger; this repository cannot supply that context.

Synthetic compatibility examples may live under `Tests/` when they verify the
pattern or compile documentation. Give them documentation-specific names, make
their artificial availability explicit, and never present them as shipped
Apple API implementations.

## Development Setup

Clone the repository, enter its root directory, and confirm the package has a
green baseline before editing:

```sh
swift --version
swift test
```

The package has no external runtime dependencies. Apple-platform behavior may
also require an appropriate SDK, simulator, or device; compilation on one host
does not demonstrate behavior on every supported platform.

## Choosing and Scoping Work

Opening an issue before a pull request is optional. Start a discussion before
implementation when requirements are ambiguous or the proposed change could
affect a public API, compatibility, deployment targets, availability or
fallback semantics, dependencies, security, privacy, data integrity, or
long-term maintenance.

Keep each pull request focused on one coherent outcome. Split unrelated fixes,
refactoring, formatting, and generated changes into separate work. Inspect and
preserve existing user changes; never revert work merely because it falls
outside the current task.

## Branch Workflow

Every change uses a short-lived branch and a pull request. Do not commit
directly to `main`.

1. Synchronize the base branch:

   ```sh
   git checkout main
   git pull --ff-only
   ```

2. Create a focused branch with one of these prefixes:

   - `feature/` for new behavior;
   - `fix/` for defect corrections;
   - `docs/` for documentation-only changes;
   - `test/` for test-only changes;
   - `chore/` for maintenance that does not fit the other categories.

3. Make the smallest sufficient change and run the required verification.
4. Open a Draft pull request and self-review the complete diff.
5. Mark it ready only when its scope is stable, required checks pass, and known
   limitations are documented.

Do not force-push a shared branch or mix unrelated work into an existing pull
request. If the base branch changes materially, update the branch without
rewriting shared history.

## Risk Classification

Classify the change before implementation and state the classification in the
pull request.

### Trivial

Non-executable text, comments, or isolated documentation corrections that do
not change a documented contract or code example.

### Standard

Backward-compatible code, tests, CI, executable documentation, or scoped
refactoring that preserves existing public behavior.

### High-risk

Any change to public API, backward compatibility, deployment targets,
`swift-tools-version`, dependencies, availability or fallback semantics,
security, privacy, or data integrity.

High-risk work requires explicit maintainer agreement on the affected contract
before implementation. Record the decision and the compatibility or rollback
consequences in the pull request. An issue may host that discussion, but an
issue is not mandatory.

## Implementation Rules

- Read `AGENTS.md`, this guide, relevant source, tests, configuration, and
  nearby implementation patterns before editing.
- Follow existing architecture, naming, formatting, and dependency patterns.
- Preserve the public API and supported deployment targets unless the approved
  scope explicitly changes them.
- Avoid unrelated refactoring, speculative optimization, and new abstractions
  without demonstrated need.
- Do not add a dependency when the repository already contains a sufficient
  mechanism.
- Modify generated files only through their authoritative generator.
- Never expose credentials, tokens, private keys, personal data, or sensitive
  logs in code, commits, issues, or pull requests.

## Backport-Specific Changes

This section governs consumer work and changes to this repository's adoption
guidance; it does not authorize concrete compatibility APIs in the package
target.

For a concrete backport design, review, migration, or removal, work in the
consumer repository and use the
[`swiftui-backport-adoption` skill](.agents/skills/swiftui-backport-adoption/SKILL.md) and the
[`Backport Adoption Guide`](docs/BACKPORT_ADOPTION_GUIDE.md). Verify native API
signatures and availability against primary Apple documentation or installed
SDK declarations.

Create or update a consumer-owned
[`backport-decision-record`](.agents/skills/swiftui-backport-adoption/assets/backport-decision-record.md)
that identifies:

- one semantic category;
- native and fallback behavior, including meaningful differences;
- the supported platform and availability matrix;
- correctness, accessibility, security, privacy, and data-integrity risks;
- native-path and fallback-path verification;
- ownership and the removal trigger.

Keep availability branching inside the compatibility layer rather than at
feature call sites. Do not claim semantic parity without evidence, and do not
present successful compilation as behavior coverage.

## Verification

Run the narrowest check that directly covers the change first. Before marking a
pull request ready, run the repository baseline from the repository root:

```sh
swift test
swift build
git diff --check
```

`RepositoryStructureTests`, included in `swift test`, validates canonical
repository files, tool bridges, and relative Markdown links. Documentation
meaning and technical accuracy remain review responsibilities.

Additional requirements depend on the affected contract:

- Behavior changes require targeted regression tests covering success, edge,
  and relevant failure paths.
- Public API changes require an explicit source- and binary-compatibility
  assessment appropriate to the package.
- Backport changes require native and fallback evidence across supported
  platform branches where practical.
- Documentation code must compile through
  [`Tests/DocumentationExamples.swift`](Tests/DocumentationExamples.swift) or be
  clearly labelled as illustrative pseudocode.
- Performance checks are required only when the change plausibly affects time,
  memory, I/O, rendering, startup, or contention.

Never report a check as successful unless it was executed and its exit status
or result was observed. When a relevant check cannot run, report the exact
command, the blocker, the behavior that remains unverified, and the resulting
confidence boundary.

## Commits and Pull Requests

Use a Conventional Commit title accepted by [`.gitlint`](.gitlint), for example:

```text
docs: add contribution workflow
```

Keep the title at 72 characters or fewer and use one of the configured types:
`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`,
`perf`, or `revert`.

Release selection is explicit and independent of commit text. Before merge,
choose at most one label according to the [`Release Guide`](docs/RELEASING.md):

- `semver:major` for the next major version;
- `semver:minor` for the next minor version;
- `semver:patch` for the next patch version.

No SemVer label is the normal no-release mode. Selecting exactly one supported
label authorizes automatic tag and GitHub Release publication after merge and
successful push CI; publication does not request another confirmation. The
label state at the pull request's merge event is final for that release. An AI
agent may change a release label only with explicit human authorization.

Open the pull request as Draft. Its description must include:

- the problem and scoped solution;
- risk classification and realistic failure modes;
- verification commands and observed outcomes;
- compatibility or public API impact;
- unverified areas and known limitations;
- material AI creation or review, plus the human verification performed.

Self-review the final diff before requesting review. A failed required check
blocks readiness and merge; fix it or report the exact unresolved blocker.

## AI-Assisted Contributions

Before modifying the repository, an AI agent must read `AGENTS.md` and this
guide. It must load the project `swiftui-backport-adoption` skill whenever
SwiftUI backport semantics are involved.

AI agents must preserve human changes, stay within the approved scope, disclose
assumptions, and never fabricate commands, tests, reviews, or results. Pull
requests must disclose material AI assistance and identify what a human
verified.

AI review is supplementary evidence and cannot count as independent human
approval. An AI agent may commit, push, publish, change pull request state, or
merge only with explicit human authorization.

## Review, Merge, and Definition of Done

A contribution is ready to merge only when all of the following are true:

- the requested behavior or documentation is complete and scoped;
- GitHub `release-label` and `build-and-test` checks are successful;
- all actionable review threads are resolved;
- every pull request has independent human approval from a reviewer other than
  the author;
- compatibility impact, risks, and limitations are documented;
- relevant verification evidence is present and no result is fabricated;
- the final diff contains no known unrelated changes.

AI approval does not satisfy the human-review requirement. Merge only after the
entire gate is met. Prefer a squash merge, then delete the short-lived branch.
