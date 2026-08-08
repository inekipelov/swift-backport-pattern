# Agent-Ready Documentation Design

## Goal

Make this package a reliable source of backport code, engineering guidance, and reusable instructions for human developers and AI coding agents without duplicating the canonical rules for Codex, Claude Code, and OpenCode.

## Audiences

1. Package adopters who need a small, correct Swift example.
2. Maintainers who need repository conventions and verification commands.
3. AI agents working in this repository.
4. AI agents applying the pattern in a consumer repository.

## Information Architecture

Use four layers with one responsibility each:

- `README.md`: installation, truthful quick start, and navigation.
- `docs/`: canonical engineering rules, decision records, and consumer-agent setup.
- `AGENTS.md`: concise repository rules and task routing loaded by Codex and OpenCode.
- `.agents/skills/backport-adoption/`: on-demand adoption workflow shared by Codex and OpenCode and bridged to Claude Code.

`CLAUDE.md` imports `AGENTS.md`. Claude's project skill path points to the canonical skill rather than duplicating its contents. No `opencode.json` or `.codex/config.toml` is needed because the supported default discovery paths cover this repository.

## Canonical Sources

Use this precedence when information conflicts:

1. Public declarations under `Sources/` and executable tests under `Tests/`.
2. `docs/BACKPORT_ADOPTION_GUIDE.md` for adoption policy.
3. `.agents/skills/backport-adoption/SKILL.md` for the repeatable workflow.
4. `README.md` for the concise public entry point.

Detailed category definitions stay in the adoption guide. The skill contains the workflow and a compact category routing table, not a second copy of the guide.

## Stable Categories

Replace section-number identifiers with semantic identifiers:

- `redirect-fallback`
- `compatibility-type`
- `behavioral-polyfill`
- `no-op-fallback`

Numbering may change as documentation evolves; semantic identifiers must not.

## Example Contract

- README examples must compile against the package's actual API.
- Documentation must label non-compilable code as illustrative pseudocode.
- Executable examples live in `Tests/DocumentationExamples.swift` so `swift test` detects drift.
- The package provides the namespace pattern; concrete Apple API backports remain in consumer modules.

## Agent Workflow

The `backport-adoption` skill triggers when an agent creates, reviews, migrates, or removes a Swift/SwiftUI compatibility API using `Backport` or `Backported`. It requires the agent to:

1. Inspect the consumer deployment targets and supported platforms.
2. Verify the native API and availability against primary Apple sources.
3. Select one semantic category and reject unsafe alternatives.
4. Record behavior deltas, risk, ownership, tests, and removal trigger.
5. Keep availability branching inside the compatibility layer.
6. Verify native and fallback paths where feasible and report coverage gaps.

The reusable decision-record template ships as a skill asset and is linked from public documentation.

## Baseline Skill Evaluation

Three fresh agents worked without the skill on creation, unsafe no-op review, and removal scenarios. The compact guide let them reason about the core pattern, but all three exposed discoverability or contract gaps:

- numeric category labels differed between committed and working-tree documentation;
- no reusable decision-record template or storage shape existed;
- README examples referenced APIs absent from the package;
- no consumer-repository skill installation path existed;
- removal guidance lacked an explicit retirement-record shape;
- repository CI could not supply the consumer's multi-platform behavior evidence.

The skill must improve output consistency and routing rather than duplicate the guide's domain content.

## Forward Skill Evaluation

Three fresh agents repeated the creation, unsafe no-op review, and removal scenarios with the skill supplied. All three used semantic category identifiers, produced the required evidence structure, and preserved the consumer-repository boundary. The review scenario blocked a no-op that could change accessibility; the removal scenario required every supported target to reach native availability before deletion.

The evaluation exposed one remaining ambiguity: the decision record had no explicit lifecycle status. The final template now records `Proposed`, `Accepted`, `Blocked`, or `Retired`, and the documentation contract prevents this field from disappearing.

## Consumer Boundary

Adding the SPM dependency does not automatically load the dependency repository's agent instructions into the consumer repository. `docs/AI_AGENT_ADOPTION.md` must explain how to copy or link the project skill into the consumer's discovery path and how Claude Code reaches the same canonical folder.

## Verification

Add a dependency-free shell contract check that verifies:

- required agent and documentation files exist;
- `CLAUDE.md` imports only `AGENTS.md`;
- the Claude skill bridge resolves to the canonical skill;
- skill frontmatter has the canonical name and a trigger-focused description;
- obsolete `AGENT-DOC` and fictitious README calls are absent;
- stable category identifiers and decision-record fields remain present.

Run the contract check in CI together with `swift test`. Validate the skill with the official local `quick_validate.py` helper during development.

## Compatibility and Scope

- Preserve `swift-tools-version: 5.0` and all current deployment targets.
- Do not add runtime dependencies or change the public Swift API.
- Defer DocC integration until its effect on the advertised Swift 5.0 toolchain support is tested separately.
- Preserve the user's compact adoption-guide direction while repairing navigation and incomplete examples.
- Do not commit or push without an explicit user request.
