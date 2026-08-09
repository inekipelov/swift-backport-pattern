# AI Agent Adoption

The package includes one canonical project skill for designing, reviewing,
migrating, and removing SwiftUI backports:

```text
.agents/skills/swiftui-backport-adoption/
```

The skill guides concrete work in consumer repositories. It does not make a
concrete backport part of this package and must not be used to add one under
this repository's `Sources/`.

## In This Repository

- Codex discovers the skill from `.agents/skills` and reads `AGENTS.md`.
- OpenCode discovers the same `.agents/skills` folder and reads `AGENTS.md`.
- Claude Code reads `CLAUDE.md`, which imports `AGENTS.md`, and discovers the same skill through `.claude/skills/swiftui-backport-adoption`.

The Claude directory symlink requires Claude Code 2.1.203 or newer. Use the wrapper fallback below for older versions or environments that do not preserve links.

Invoke it explicitly when needed:

- Codex: `Use $swiftui-backport-adoption to review this compatibility API.`
- Claude Code: `/swiftui-backport-adoption review this compatibility API.`
- OpenCode: ask the agent to load and use the `swiftui-backport-adoption` skill.

## In a Consumer Repository

Adding the Swift package dependency does not add the package repository's root instructions to the consumer repository's agent context. Vendor the skill separately when agents in the consumer repository should follow this workflow.

1. Copy `.agents/skills/swiftui-backport-adoption` from a tagged package checkout into the consumer repository at the same path.
2. Add the consumer repository's build, test, platform, and architecture rules to its own `AGENTS.md`.
3. For Claude Code, create `.claude/skills/swiftui-backport-adoption` as a relative link to `../../.agents/skills/swiftui-backport-adoption`.
4. If the consumer already has a `CLAUDE.md`, import `@AGENTS.md` from it instead of duplicating shared rules.
5. Review skill changes when updating the package version; do not overwrite consumer-specific repository guidance.

On macOS, create the Claude skill bridge from the consumer repository root:

```sh
mkdir -p .claude/skills
ln -s ../../.agents/skills/swiftui-backport-adoption .claude/skills/swiftui-backport-adoption
```

If links are unavailable in the consumer environment, keep a small Claude wrapper that directs the agent to read the canonical `.agents/skills/swiftui-backport-adoption/SKILL.md`; do not maintain a second full workflow.

## Required Consumer Context

Before using the skill, provide or let the agent discover:

- the consumer repository and module that own the concrete compatibility API;
- minimum deployment targets and supported platforms;
- the native API declaration and availability;
- required behavior and acceptable semantic deltas;
- affected call sites and helpers;
- executable build, test, snapshot, accessibility, or UI-validation commands;
- the repository's decision-record convention and the path selected for this
  decision;
- a named owner and planned removal release;
- compiler and toolchain availability for checking the supported platform
  branches; and
- the warning policy: whether compiler-enforced deprecation is expected, and
  how warnings initiate removal work.

The skill cannot infer missing product semantics, ownership, lifecycle, or
platform validation from this pattern package alone. When a material semantic,
ownership, verification, or lifecycle input is missing, it must return a
`Blocked` decision handoff: include the readiness table, the exact gap, the
safe next action, and verified facts rather than speculating or implementing.

## Official Tool Documentation

- OpenAI: [AGENTS.md](https://developers.openai.com/codex/guides/agents-md) and [Codex skills](https://developers.openai.com/codex/skills)
- Anthropic: [CLAUDE.md and imports](https://code.claude.com/docs/en/memory) and [Claude Code skills](https://code.claude.com/docs/en/skills)
- OpenCode: [rules](https://opencode.ai/docs/rules/) and [agent skills](https://opencode.ai/docs/skills)
