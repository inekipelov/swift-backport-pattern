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

reject_file() {
    if [ -e "$1" ]; then
        fail "obsolete file must not exist: $1"
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
require_file CONTRIBUTING.md
require_file docs/README.md
require_file docs/AI_AGENT_ADOPTION.md
require_file docs/BACKPORT_ADOPTION_GUIDE.md
require_file Tests/DocumentationExamples.swift
require_file .agents/skills/backport-adoption/SKILL.md
require_file .agents/skills/backport-adoption/agents/openai.yaml
require_file .agents/skills/backport-adoption/assets/backport-decision-record.md
require_file .gitlint
require_file .github/workflows/ci.yml
require_file .github/workflows/release.yml
require_file .github/release.yml
require_file docs/RELEASING.md
require_file scripts/validate-release-labels.sh
require_file scripts/release-labels-at-merge.sh
require_file scripts/latest-stable-version.sh
require_file scripts/next-semver.sh
require_file scripts/plan-release.sh
require_file scripts/release-context-for-sha.sh
require_file scripts/publish-release.sh
require_file scripts/test-release-contract.sh
require_file scripts/test-publish-release.sh
require_file scripts/test-fixtures/fake-release-gh.sh
require_file scripts/test-fixtures/fake-release-sleep.sh

reject_file .github/workflows/build.yml
reject_file .github/workflows/test.yml
reject_file .github/workflows/gitlint.yml

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
require_text CONTRIBUTING.md '[`Release Guide`](docs/RELEASING.md)'
require_text CONTRIBUTING.md '`semver:major`'
require_text CONTRIBUTING.md '`semver:minor`'
require_text CONTRIBUTING.md '`semver:patch`'
require_text CONTRIBUTING.md '`release-label`'
require_text CONTRIBUTING.md '`build-and-test`'
reject_text CONTRIBUTING.md 'GitHub Build, Test, and Gitlint checks are successful'
require_text README.md '[Contributing](CONTRIBUTING.md)'
require_text docs/README.md '[Contribution Workflow](../CONTRIBUTING.md)'
require_text docs/README.md '[Release Guide](RELEASING.md)'
require_text AGENTS.md '`CONTRIBUTING.md` owns the contribution workflow'
require_text AGENTS.md '`docs/RELEASING.md` owns release authorization'

require_text .github/workflows/ci.yml 'contents: read'
reject_text .github/workflows/ci.yml 'contents: write'
require_text .github/workflows/release.yml 'workflow_run:'
require_text .github/workflows/release.yml "github.event.workflow_run.conclusion == 'success'"
require_text .github/workflows/release.yml "github.event.workflow.path == '.github/workflows/ci.yml'"
require_text .github/workflows/release.yml 'github.event.workflow.id == github.event.workflow_run.workflow_id'
require_text .github/workflows/release.yml "github.event.workflow_run.event == 'push'"
require_text .github/workflows/release.yml "github.event.workflow_run.head_branch == 'main'"
require_text .github/workflows/release.yml 'github.event.workflow_run.head_repository.full_name == github.repository'
require_text .github/workflows/release.yml 'contents: write'
require_text .github/workflows/release.yml 'TARGET_SHA: ${{ github.event.workflow_run.head_sha }}'
require_text .github/workflows/release.yml '          ref: main'
require_text .github/workflows/release.yml '          fetch-depth: 0'
require_text .github/workflows/release.yml 'git merge-base --is-ancestor "$TARGET_SHA" origin/main'
require_text .github/workflows/release.yml 'scripts/publish-release.sh "$GITHUB_REPOSITORY" "$TARGET_SHA"'
reject_text .github/workflows/release.yml 'github.event.workflow_run.path =='
reject_text .github/workflows/release.yml 'ref: ${{ github.event.workflow_run.head_sha }}'
reject_text .github/workflows/release.yml 'ref: ${{ env.TARGET_SHA }}'
reject_text .github/workflows/release.yml 'actions/download-artifact@'
reject_text .github/workflows/release.yml 'actions/upload-artifact@'
reject_text .github/workflows/release.yml 'actions/cache@'
reject_text .github/workflows/release.yml 'gh run download'
reject_text .github/workflows/release.yml '/artifacts'
reject_text .github/workflows/release.yml 'cache:'

for workflow in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$workflow" ] || continue
    [ "$workflow" = .github/workflows/release.yml ] || \
        reject_text "$workflow" ': write'
done

require_text scripts/publish-release.sh 'git fetch --quiet --force --prune --prune-tags --tags origin'
require_text scripts/publish-release.sh '[ "$checkout_sha" = "$main_sha" ]'
require_text scripts/publish-release.sh 'validate_remote_release_tag "$version" "$target_sha"'
require_text scripts/publish-release.sh "grep -Eq 'HTTP 422([^0-9]|$)'"
require_text scripts/publish-release.sh "grep -Fq 'Reference already exists'"
require_text scripts/publish-release.sh '[ "$conflict_previous" = "$planned_previous" ]'
require_text scripts/publish-release.sh '[ "$conflict_version" = "$planned_version" ]'

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
