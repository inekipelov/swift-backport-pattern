#!/bin/sh

set -u

failures=0

fail() {
    printf '%s\n' "documentation contract: $1" >&2
    failures=$((failures + 1))
}

require_file() {
    if [ ! -f "$1" ]; then
        fail "missing required file: $1"
    fi
}

require_text() {
    file=$1
    text=$2

    if [ -f "$file" ] && ! grep -Fq -- "$text" "$file"; then
        fail "$file must contain: $text"
    fi
}

reject_text() {
    file=$1
    text=$2

    if [ -f "$file" ] && grep -Fq -- "$text" "$file"; then
        fail "$file must not contain: $text"
    fi
}

require_file AGENTS.md
require_file CLAUDE.md
require_file docs/README.md
require_file docs/AI_AGENT_ADOPTION.md
require_file docs/BACKPORT_ADOPTION_GUIDE.md
require_file Tests/DocumentationExamples.swift
require_file .agents/skills/backport-adoption/SKILL.md
require_file .agents/skills/backport-adoption/agents/openai.yaml
require_file .agents/skills/backport-adoption/assets/backport-decision-record.md

if [ -f CLAUDE.md ]; then
    claude_lines=$(awk 'END { print NR }' CLAUDE.md)
    claude_content=$(sed -n '1p' CLAUDE.md)
    if [ "$claude_lines" -ne 1 ] || [ "$claude_content" != '@AGENTS.md' ]; then
        fail "CLAUDE.md must contain exactly @AGENTS.md"
    fi
fi

if [ ! -L .claude/skills/backport-adoption ]; then
    fail ".claude/skills/backport-adoption must be a symlink"
else
    claude_skill_target=$(readlink .claude/skills/backport-adoption)
    if [ "$claude_skill_target" != '../../.agents/skills/backport-adoption' ]; then
        fail ".claude skill must target ../../.agents/skills/backport-adoption"
    fi
fi

require_text .agents/skills/backport-adoption/SKILL.md 'name: backport-adoption'
require_text .agents/skills/backport-adoption/SKILL.md 'description: Use when'
require_text .agents/skills/backport-adoption/agents/openai.yaml 'default_prompt: "Use $backport-adoption'

require_text docs/BACKPORT_ADOPTION_GUIDE.md '`redirect-fallback`'
require_text docs/BACKPORT_ADOPTION_GUIDE.md '`compatibility-type`'
require_text docs/BACKPORT_ADOPTION_GUIDE.md '`behavioral-polyfill`'
require_text docs/BACKPORT_ADOPTION_GUIDE.md '`no-op-fallback`'
require_text docs/BACKPORT_ADOPTION_GUIDE.md 'Tests/DocumentationExamples.swift'
require_text docs/BACKPORT_ADOPTION_GUIDE.md 'backport-decision-record.md'
require_text README.md 'import Foundation'
require_text docs/AI_AGENT_ADOPTION.md 'https://developers.openai.com/codex/guides/agents-md'
require_text docs/AI_AGENT_ADOPTION.md 'https://developers.openai.com/codex/skills'
require_text docs/AI_AGENT_ADOPTION.md 'https://code.claude.com/docs/en/memory'
require_text docs/AI_AGENT_ADOPTION.md 'https://code.claude.com/docs/en/skills'
require_text docs/AI_AGENT_ADOPTION.md 'https://opencode.ai/docs/rules/'
require_text docs/AI_AGENT_ADOPTION.md 'https://opencode.ai/docs/skills'

require_text .agents/skills/backport-adoption/assets/backport-decision-record.md '## Context'
require_text .agents/skills/backport-adoption/assets/backport-decision-record.md '- Status:'
require_text .agents/skills/backport-adoption/assets/backport-decision-record.md '## Category'
require_text .agents/skills/backport-adoption/assets/backport-decision-record.md '## Behavior Contract'
require_text .agents/skills/backport-adoption/assets/backport-decision-record.md '## Risk'
require_text .agents/skills/backport-adoption/assets/backport-decision-record.md '## Platform Matrix'
require_text .agents/skills/backport-adoption/assets/backport-decision-record.md '## Verification'
require_text .agents/skills/backport-adoption/assets/backport-decision-record.md '## Ownership and Removal'

reject_text README.md 'AGENT-DOC:'
reject_text README.md 'modernFeature()'
reject_text README.md 'modernModifier()'
reject_text Sources/Backport.swift 'MyView()'
reject_text Sources/SwiftUI+Backport.swift 'someModernFeature()'
reject_text Sources/ObjCRuntime+Backport.swift 'UILabel()'

if [ "$failures" -ne 0 ]; then
    exit 1
fi

printf '%s\n' 'documentation contract: OK'
