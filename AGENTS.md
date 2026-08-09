# Repository Guidance

## Purpose

This Swift package provides the `Backport`/`Backported` namespace pattern plus reference material for designing compatibility APIs. Concrete compatibility APIs are out of scope for `Sources/`. Their implementations, fallback semantics, validation, ownership, and removal lifecycle belong in consumer app or package modules.

## Sources of Truth

Use sources in this order when they conflict:

1. Public declarations under `Sources/` and executable behavior under `Tests/`.
2. `docs/BACKPORT_ADOPTION_GUIDE.md` for backport selection and lifecycle rules.
3. `.agents/skills/swiftui-backport-adoption/SKILL.md` for the repeatable SwiftUI create, review, migration, and removal workflow.
4. `README.md` for the concise public entry point.

`CONTRIBUTING.md` owns the contribution workflow, including branches, pull requests, review, and merge requirements.

`docs/RELEASING.md` owns release authorization, SemVer calculation, publication, and recovery policy.

## Task Routing

- Before changing the repository, read `CONTRIBUTING.md` and follow its scope, branch, verification, review, and merge workflow.
- For package API changes, inspect `Package.swift`, `Sources/`, and affected tests first; keep changes limited to the reusable namespace mechanism.
- For a concrete SwiftUI backport design, review, migration, or removal, work in the consumer repository and use the `swiftui-backport-adoption` skill plus the adoption guide.
- If a concrete backport is requested in this repository, stop and request the consumer repository and its product context instead of adding the API here.
- For documentation changes, preserve stable category identifiers and keep consumer reference examples consistent with their documented contracts.
- For release labels, version calculation, tag or GitHub Release work, read `docs/RELEASING.md` and preserve its human-authorization boundary.
- For consumer-project work, obtain that repository's deployment targets, supported platforms, architecture, tests, and release policy before making a recommendation.

## Engineering Rules

- Keep the package dependency-free and preserve `swift-tools-version: 5.0` unless the user explicitly approves a compatibility change.
- Preserve existing deployment targets and public API unless the task explicitly changes them.
- Do not add concrete Apple API methods, compatibility types, fallback implementations, or product policy to the package target.
- Keep availability and platform branching inside the compatibility layer, not at feature call sites.
- Do not claim semantic parity without evidence. State user-visible, accessibility, correctness, security, and data-integrity deltas.
- Treat Apple documentation and SDK declarations as primary sources for API signatures and availability.
- Preserve unrelated user changes and keep diffs scoped.

## Documentation Rules

- README examples must use package APIs or be identified as consumer-owned reference code.
- Keep concrete compatibility implementations in documentation and skill references, not in the package test target.
- Label incomplete code as illustrative pseudocode and do not present reference snippets as package validation.
- Use semantic identifiers: `redirect-fallback`, `compatibility-type`, `behavioral-polyfill`, and `no-op-fallback`.
- Keep `CLAUDE.md` exactly `@AGENTS.md`; do not duplicate repository rules in tool-specific files.
- Keep the canonical project skill under `.agents/skills/swiftui-backport-adoption`.

## Verification

Run the narrowest relevant checks, then the full affected set:

```sh
swift test
swift build
git diff --check
```

`RepositoryStructureTests` covers canonical repository files, tool bridges, and
relative Markdown links without constraining documentation wording.

Report platform branches that cannot be executed locally or in CI. Do not present compile coverage as behavior coverage.

## Git Scope

Do not commit, push, publish, or change release state unless the user explicitly requests it.
