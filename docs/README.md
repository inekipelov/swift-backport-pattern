# Documentation

This directory contains the public engineering guidance for the Backport pattern.

## Start Here

| Need | Source |
| --- | --- |
| Install the package or understand its public surface | [Package README](../README.md) |
| Choose, implement, verify, or remove a backport | [Backport Adoption Guide](BACKPORT_ADOPTION_GUIDE.md) |
| Configure a consumer repository's AI agent | [AI Agent Adoption](AI_AGENT_ADOPTION.md) |
| Copy a decision-record structure | [Backport Decision Record](../.agents/skills/backport-adoption/assets/backport-decision-record.md) |
| Inspect compiled usage patterns | [Documentation Examples](../Tests/DocumentationExamples.swift) |

## Source Precedence

When documentation conflicts, use this order:

1. `Sources/` declarations and executable `Tests/`.
2. `BACKPORT_ADOPTION_GUIDE.md` for engineering policy.
3. `.agents/skills/backport-adoption/SKILL.md` for the repeatable agent workflow.
4. Root `README.md` for the concise overview.

Planning records under `docs/superpowers/` explain repository changes. They are not adoption policy.
