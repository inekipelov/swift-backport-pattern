# Documentation

This directory contains the public engineering guidance for the Backport pattern.

The package implements only the reusable namespace mechanism. Concrete Apple
API backports and their lifecycle records belong to consumer repositories;
examples in this repository are synthetic pattern fixtures.

## Start Here

| Need | Source |
| --- | --- |
| Install the package or understand its public surface | [Package README](../README.md) |
| Contribute code, tests, or documentation | [Contribution Workflow](../CONTRIBUTING.md) |
| Select a version bump or recover a release | [Release Guide](RELEASING.md) |
| Choose, implement, verify, or remove a backport | [Backport Adoption Guide](BACKPORT_ADOPTION_GUIDE.md) |
| Compare the four SwiftUI fallback categories | [SwiftUI Category Examples](../.agents/skills/swiftui-backport-adoption/references/category-examples.md) |
| Configure a consumer repository's AI agent | [AI Agent Adoption](AI_AGENT_ADOPTION.md) |
| Copy a decision-record structure | [Backport Decision Record](../.agents/skills/swiftui-backport-adoption/assets/backport-decision-record.md) |

## Source Precedence

When documentation conflicts, use this order:

1. `Sources/` declarations and executable `Tests/`.
2. Root `CONTRIBUTING.md` for branch, review, and merge workflow.
3. `RELEASING.md` for release authorization, versioning, publication, and recovery policy.
4. `BACKPORT_ADOPTION_GUIDE.md` for engineering policy.
5. `.agents/skills/swiftui-backport-adoption/SKILL.md` for the repeatable SwiftUI agent workflow.
6. Root `README.md` for the concise overview.
