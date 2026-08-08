# Repository Guidance

## Purpose

This Swift package provides the `Backport`/`Backported` namespace pattern plus reference material for designing compatibility APIs. Concrete Apple API backports belong in consumer app or package modules unless the user explicitly expands this package's public API.

## Sources of Truth

Use sources in this order when they conflict:

1. Public declarations under `Sources/` and executable behavior under `Tests/`.
2. `docs/BACKPORT_ADOPTION_GUIDE.md` for backport selection and lifecycle rules.
3. `.agents/skills/backport-adoption/SKILL.md` for the repeatable create, review, migration, and removal workflow.
4. `README.md` for the concise public entry point.

`CONTRIBUTING.md` owns the contribution workflow, including branches, pull requests, review, and merge requirements.

## Task Routing

- Before changing the repository, read `CONTRIBUTING.md` and follow its scope, branch, verification, review, and merge workflow.
- For package API changes, inspect `Package.swift`, `Sources/`, and affected tests first.
- For a concrete backport design, review, migration, or removal, use the `backport-adoption` skill and the adoption guide.
- For documentation changes, preserve stable category identifiers and update compiled examples when code changes.
- For consumer-project work, obtain that repository's deployment targets, supported platforms, architecture, tests, and release policy before making a recommendation.

## Engineering Rules

- Keep the package dependency-free and preserve `swift-tools-version: 5.0` unless the user explicitly approves a compatibility change.
- Preserve existing deployment targets and public API unless the task explicitly changes them.
- Keep availability and platform branching inside the compatibility layer, not at feature call sites.
- Do not claim semantic parity without evidence. State user-visible, accessibility, correctness, security, and data-integrity deltas.
- Treat Apple documentation and SDK declarations as primary sources for API signatures and availability.
- Preserve unrelated user changes and keep diffs scoped.

## Documentation Rules

- README examples must compile against APIs present in this repository.
- Put executable examples in `Tests/DocumentationExamples.swift`.
- Label non-executable code as illustrative pseudocode.
- Use semantic identifiers: `redirect-fallback`, `compatibility-type`, `behavioral-polyfill`, and `no-op-fallback`.
- Keep `CLAUDE.md` exactly `@AGENTS.md`; do not duplicate repository rules in tool-specific files.
- Keep the canonical project skill under `.agents/skills/backport-adoption`.

## Verification

Run the narrowest relevant checks, then the full affected set:

```sh
sh scripts/validate-documentation.sh
swift test
swift build
git diff --check
```

Report platform branches that cannot be executed locally or in CI. Do not present compile coverage as behavior coverage.

## Git Scope

Do not commit, push, publish, or change release state unless the user explicitly requests it.
