# SemVer Release Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate SwiftPM build and test into one read-only CI pipeline and publish stable GitHub Releases only after a successfully verified merge explicitly authorizes one SemVer bump.

**Architecture:** `.github/workflows/ci.yml` owns the read-only pull request and `main` verification gate, compiling sources and tests once before executing the prebuilt test bundle. A separate `.github/workflows/release.yml` runs from the default branch after successful push CI, reconstructs labels at the merge boundary, delegates deterministic decisions to tested POSIX shell scripts, and receives the only write-capable token.

**Tech Stack:** Swift Package Manager, XCTest, POSIX shell, GitHub Actions, GitHub REST API through `gh`, `jq`, `xcbeautify`, Markdown, GitHub repository rulesets.

## Global Constraints

- Preserve `swift-tools-version: 5.0`, deployment targets, public Swift API, and the dependency-free package manifest.
- Keep package and runtime products dependency-free. Pure label/version policy uses POSIX shell and standard Unix tools; the deterministic planner additionally requires a full-history checkout and runner-provided `git`; GitHub adapters also require runner-provided `gh` and `jq`; CI output formatting requires runner-provided `xcbeautify`. Assert and print their versions in the owning workflows.
- Keep `.gitlint` and Conventional Commit titles as a local contribution rule; remove only the Gitlint GitHub Actions workflow and required check.
- Use exactly `semver:major`, `semver:minor`, and `semver:patch`; zero labels means no release, one authorizes immediate stable publication, and multiple or unsupported `semver:*` labels fail closed.
- Publish unprefixed, lightweight, stable `X.Y.Z` tags; do not create prereleases or rewrite historical tags and Releases.
- Keep pull request CI read-only. The write-capable publication workflow must never run pull request code, restore pull request caches, or consume pull request artifacts.
- Pin `actions/checkout` to commit `de0fac2e4500dabe0009e67214ff5f5447ce83dd` (`v6.0.2`) and set `persist-credentials: false` in every checkout.
- Use `macos-15` for build and test, `ubuntu-24.04` for policy and publication jobs, and record the active Xcode, Swift, and `xcbeautify` versions.
- Do not cache `.build` across workflow runs; reuse it only inside the single `build-and-test` job.
- Never overwrite or force-push a tag, edit or delete a published Release, or infer a bump from commit text.
- Preserve the active ruleset's existing conditions and rules; add only required status contexts `release-label` and `build-and-test` after both have succeeded on the Draft pull request.
- Leave pull request #3 without a `semver:*` label unless the maintainer separately authorizes a release.
- Do not change Swift sources, XCTest sources, `Package.swift`, merge methods, review requirements, or historical planning records.

---

## File Structure

### Create

- `.github/workflows/ci.yml`: read-only label, documentation, build, and test gate.
- `.github/workflows/release.yml`: trusted `workflow_run` publication boundary.
- `.github/release.yml`: generated release-note categories.
- `scripts/validate-release-labels.sh`: newline-delimited label set to one bump or no bump.
- `scripts/release-labels-at-merge.sh`: normalized timeline events to the labels active at merge.
- `scripts/latest-stable-version.sh`: strict stable tag stream to numeric maximum.
- `scripts/next-semver.sh`: strict version plus bump to next version.
- `scripts/plan-release.sh`: normalized repository state to `noop`, `wait`, `resume`, or `create`.
- `scripts/release-context-for-sha.sh`: read-only GitHub adapter for the merged pull request and merge-time bump.
- `scripts/publish-release.sh`: trusted polling, refresh, tag, notes, and Release adapter.
- `scripts/test-release-contract.sh`: offline executable contract for pure release policy and the read-only GitHub adapter fixtures.
- `scripts/test-publish-release.sh`: disposable-Git behavioral contract for the write-capable publisher.
- `scripts/test-fixtures/fake-gh.sh`: read-only association/timeline API fixture.
- `scripts/test-fixtures/fake-release-gh.sh`: stateful tag/Release API fixture.
- `scripts/test-fixtures/fake-release-sleep.sh`: zero-delay predecessor publication fixture.
- `docs/RELEASING.md`: canonical maintainer and AI-agent release contract.

### Modify

- `scripts/validate-documentation.sh`: require the release surfaces and enforce the trust boundary.
- `CONTRIBUTING.md`: document label authorization and the two required checks.
- `AGENTS.md`: route release work without weakening Git scope.
- `docs/README.md`: add the release guide to the documentation map and ownership order.

### Delete

- `.github/workflows/build.yml`
- `.github/workflows/test.yml`
- `.github/workflows/gitlint.yml`

---

### Task 1: Make merge-time release labels executable

**Files:**
- Create: `scripts/test-release-contract.sh`
- Create: `scripts/validate-release-labels.sh`
- Create: `scripts/release-labels-at-merge.sh`

**Interfaces:**
- `validate-release-labels.sh` consumes one label per stdin line and prints exactly `major`, `minor`, `patch`, or one empty line. It exits nonzero for more than one supported-label record or an active unsupported `semver:*`; unrelated labels are ignored.
- `release-labels-at-merge.sh` consumes API-order TSV records `labeled<TAB>NAME`, `unlabeled<TAB>NAME`, or `merged`. It prints the labels active at the only merge boundary, ignores label changes after that boundary, and exits nonzero for malformed input or zero/multiple `merged` records.
- `test-release-contract.sh` is invoked as `sh scripts/test-release-contract.sh` and exits nonzero when any assertion fails.

- [ ] **Step 1: Write the failing label and timeline assertions**

Create the test harness with these helpers and cases:

```sh
#!/bin/sh

set -u

failures=0

fail() {
    printf '%s\n' "release contract: $1" >&2
    failures=$((failures + 1))
}

assert_equal() {
    description=$1
    expected=$2
    actual=$3
    if [ "$actual" != "$expected" ]; then
        fail "$description: expected '$expected', got '$actual'"
    fi
}

assert_failure() {
    description=$1
    shift
    if "$@" >/dev/null 2>&1; then
        fail "$description: expected failure"
    fi
}

assert_equal 'zero labels' '' "$(printf '' | sh scripts/validate-release-labels.sh)"
assert_equal 'patch label' 'patch' "$(printf '%s\n' 'semver:patch' | sh scripts/validate-release-labels.sh)"
assert_equal 'unrelated plus minor' 'minor' "$(printf '%s\n' 'documentation' 'semver:minor' | sh scripts/validate-release-labels.sh)"
assert_failure 'conflicting labels' sh -c "printf '%s\n' 'semver:minor' 'semver:patch' | sh scripts/validate-release-labels.sh"
assert_failure 'duplicate supported label input' sh -c "printf '%s\n' 'semver:patch' 'semver:patch' | sh scripts/validate-release-labels.sh"
assert_failure 'unsupported semver label' sh -c "printf '%s\n' 'semver:beta' | sh scripts/validate-release-labels.sh"

timeline_output=$(printf '%s\t%s\n%s\t%s\n%s\n%s\t%s\n' \
    labeled semver:major \
    unlabeled semver:major \
    merged \
    labeled semver:patch | sh scripts/release-labels-at-merge.sh)
assert_equal 'post-merge labels ignored' '' "$timeline_output"

timeline_output=$(printf '%s\t%s\n%s\n' \
    labeled semver:minor \
    merged | sh scripts/release-labels-at-merge.sh)
assert_equal 'label active at merge' 'semver:minor' "$timeline_output"

assert_failure 'missing merge boundary' sh -c "printf '%s\\t%s\\n' labeled semver:patch | sh scripts/release-labels-at-merge.sh"
assert_failure 'multiple merge boundaries' sh -c "printf '%s\\n%s\\n' merged merged | sh scripts/release-labels-at-merge.sh"

if [ "$failures" -ne 0 ]; then
    exit 1
fi

printf '%s\n' 'release contract: OK'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```sh
sh scripts/test-release-contract.sh
```

Expected: nonzero exit because both policy scripts are absent.

- [ ] **Step 3: Implement label validation**

Create `scripts/validate-release-labels.sh` with this state machine:

```sh
#!/bin/sh

set -eu

selected=

while IFS= read -r label || [ -n "$label" ]; do
    case "$label" in
        semver:major) bump=major ;;
        semver:minor) bump=minor ;;
        semver:patch) bump=patch ;;
        semver:*)
            printf '%s\n' "release labels: unsupported label: $label" >&2
            exit 1
            ;;
        *) continue ;;
    esac

    if [ -n "$selected" ]; then
        printf '%s\n' "release labels: multiple release labels: $selected and $bump" >&2
        exit 1
    fi
    selected=$bump
done

printf '%s\n' "$selected"
```

- [ ] **Step 4: Implement merge-boundary replay**

Create `scripts/release-labels-at-merge.sh` with integer state for the three supported labels and one unsupported-active count. Read the whole stream so a second `merged` record is rejected, but freeze label state after the first boundary:

```sh
#!/bin/sh

set -eu

major=0
minor=0
patch=0
unsupported=0
merge_count=0
frozen_major=0
frozen_minor=0
frozen_patch=0
frozen_unsupported=0
tab=$(printf '\t')

while IFS="$tab" read -r event label extra || [ -n "$event${label:-}${extra:-}" ]; do
    [ -z "${extra:-}" ] || { printf '%s\n' 'release timeline: malformed record' >&2; exit 1; }
    case "$event" in
        labeled|unlabeled)
            [ -n "${label:-}" ] || { printf '%s\n' 'release timeline: missing label' >&2; exit 1; }
            [ "$merge_count" -eq 0 ] || continue
            value=1
            [ "$event" = labeled ] || value=0
            case "$label" in
                semver:major) major=$value ;;
                semver:minor) minor=$value ;;
                semver:patch) patch=$value ;;
                semver:*)
                    if [ "$event" = labeled ]; then
                        unsupported=$((unsupported + 1))
                    elif [ "$unsupported" -gt 0 ]; then
                        unsupported=$((unsupported - 1))
                    fi
                    ;;
            esac
            ;;
        merged)
            [ -z "${label:-}" ] || { printf '%s\n' 'release timeline: merged record has a label' >&2; exit 1; }
            merge_count=$((merge_count + 1))
            [ "$merge_count" -eq 1 ] || { printf '%s\n' 'release timeline: multiple merge boundaries' >&2; exit 1; }
            frozen_major=$major
            frozen_minor=$minor
            frozen_patch=$patch
            frozen_unsupported=$unsupported
            ;;
        *)
            printf '%s\n' "release timeline: unsupported event: $event" >&2
            exit 1
            ;;
    esac
done

[ "$merge_count" -eq 1 ] || { printf '%s\n' 'release timeline: missing merge boundary' >&2; exit 1; }
[ "$frozen_major" -eq 0 ] || printf '%s\n' 'semver:major'
[ "$frozen_minor" -eq 0 ] || printf '%s\n' 'semver:minor'
[ "$frozen_patch" -eq 0 ] || printf '%s\n' 'semver:patch'
[ "$frozen_unsupported" -eq 0 ] || printf '%s\n' 'semver:unsupported'
```

- [ ] **Step 5: Verify GREEN and shell syntax**

Run:

```sh
sh -n scripts/validate-release-labels.sh scripts/release-labels-at-merge.sh scripts/test-release-contract.sh
sh scripts/test-release-contract.sh
```

Expected: syntax checks exit zero and the test ends with
`release contract: OK`. The final harness block was added in Step 1; keep every
later assertion before that block.

- [ ] **Step 6: Commit the executable label contract**

```sh
git add scripts/validate-release-labels.sh scripts/release-labels-at-merge.sh scripts/test-release-contract.sh
git commit -m "ci: add semver label contract"
```

---

### Task 2: Add deterministic stable-version helpers

**Files:**
- Modify: `scripts/test-release-contract.sh`
- Create: `scripts/latest-stable-version.sh`
- Create: `scripts/next-semver.sh`

**Interfaces:**
- `latest-stable-version.sh` consumes tag names on stdin, ignores anything outside strict unprefixed stable `X.Y.Z`, compares each decimal component numerically without `sort -V`, and fails when no stable tag exists.
- `next-semver.sh VERSION BUMP` accepts strict stable `VERSION` and `major`, `minor`, or `patch`, then prints the next version without integer-size assumptions.

- [ ] **Step 1: Append failing SemVer matrix tests**

Add these assertions before the harness's final failure check:

```sh
assert_equal 'patch transition' '0.2.1' "$(sh scripts/next-semver.sh 0.2.0 patch)"
assert_equal 'minor transition' '0.3.0' "$(sh scripts/next-semver.sh 0.2.0 minor)"
assert_equal 'major transition' '1.0.0' "$(sh scripts/next-semver.sh 0.2.0 major)"
assert_equal 'decimal carry' '0.10.0' "$(sh scripts/next-semver.sh 0.9.9 minor)"
assert_equal 'large decimal carry' '10.0.0' "$(sh scripts/next-semver.sh 9.9.9 major)"
assert_failure 'leading zero version' sh scripts/next-semver.sh 01.2.3 patch
assert_failure 'prerelease version' sh scripts/next-semver.sh 1.2.3-rc.1 patch
assert_failure 'missing version component' sh scripts/next-semver.sh 1.2 patch
assert_failure 'whitespace in version' sh scripts/next-semver.sh ' 1.2.3' patch
assert_failure 'unsupported bump' sh scripts/next-semver.sh 1.2.3 build

latest=$(printf '%s\n' 0.9.9 0.10.0 01.0.0 v9.0.0 1.0.0-rc.1 notes 2.0.0+build | sh scripts/latest-stable-version.sh)
assert_equal 'numeric stable maximum' '0.10.0' "$latest"
assert_failure 'missing stable baseline' sh -c "printf '%s\n' v1.0.0 1.0.0-rc.1 | sh scripts/latest-stable-version.sh"
```

- [ ] **Step 2: Run the expanded test to verify RED**

Run `sh scripts/test-release-contract.sh`.

Expected: nonzero exit because both version helpers are absent.

- [ ] **Step 3: Implement strict validation and decimal increment**

In `scripts/next-semver.sh`, validate with:

```sh
[ "$#" -eq 2 ] || { printf '%s\n' 'usage: next-semver.sh VERSION BUMP' >&2; exit 2; }
stable_pattern='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
printf '%s\n' "$1" | grep -Eq "$stable_pattern" || {
    printf '%s\n' "semver: invalid stable version: $1" >&2
    exit 1
}
```

Use this width-independent decimal increment and exact split:

```sh
decimal_increment() {
    digits=$1
    result=
    carry=1
    while [ -n "$digits" ]; do
        prefix=${digits%?}
        digit=${digits#"$prefix"}
        if [ "$carry" -eq 1 ]; then
            case "$digit" in
                0) digit=1; carry=0 ;; 1) digit=2; carry=0 ;;
                2) digit=3; carry=0 ;; 3) digit=4; carry=0 ;;
                4) digit=5; carry=0 ;; 5) digit=6; carry=0 ;;
                6) digit=7; carry=0 ;; 7) digit=8; carry=0 ;;
                8) digit=9; carry=0 ;; 9) digit=0 ;;
            esac
        fi
        result=$digit$result
        digits=$prefix
    done
    [ "$carry" -eq 0 ] || result=1$result
    printf '%s\n' "$result"
}

version=$1
bump=$2
old_ifs=$IFS
IFS=.
set -- $version
IFS=$old_ifs
major=$1
minor=$2
patch=$3
```

Then use these exact transitions:

```sh
case "$bump" in
    major) major=$(decimal_increment "$major"); minor=0; patch=0 ;;
    minor) minor=$(decimal_increment "$minor"); patch=0 ;;
    patch) patch=$(decimal_increment "$patch") ;;
    *) printf '%s\n' "semver: unsupported bump: $bump" >&2; exit 1 ;;
esac
printf '%s.%s.%s\n' "$major" "$minor" "$patch"
```

- [ ] **Step 4: Implement numeric stable-tag selection**

In `scripts/latest-stable-version.sh`, set `LC_ALL=C`, reuse the strict regex,
and compare components with length first and lexical order second:

```sh
component_gt() {
    left=$1
    right=$2
    [ "${#left}" -gt "${#right}" ] && return 0
    [ "${#left}" -lt "${#right}" ] && return 1
    LC_ALL=C expr "x$left" \> "x$right" >/dev/null
}
```

Implement the comparison and selection loop exactly:

```sh
version_gt() {
    candidate=$1
    current=$2
    old_ifs=$IFS
    IFS=.
    set -- $candidate
    IFS=$old_ifs
    candidate_major=$1
    candidate_minor=$2
    candidate_patch=$3
    IFS=.
    set -- $current
    IFS=$old_ifs
    current_major=$1
    current_minor=$2
    current_patch=$3

    if [ "$candidate_major" != "$current_major" ]; then
        component_gt "$candidate_major" "$current_major"
        return
    fi
    if [ "$candidate_minor" != "$current_minor" ]; then
        component_gt "$candidate_minor" "$current_minor"
        return
    fi
    component_gt "$candidate_patch" "$current_patch"
}

latest=
while IFS= read -r tag || [ -n "$tag" ]; do
    printf '%s\n' "$tag" | grep -Eq "$stable_pattern" || continue
    if [ -z "$latest" ] || version_gt "$tag" "$latest"; then
        latest=$tag
    fi
done

[ -n "$latest" ] || {
    printf '%s\n' 'semver: no stable version tags found' >&2
    exit 1
}
printf '%s\n' "$latest"
```

- [ ] **Step 5: Verify the complete version matrix**

```sh
sh -n scripts/latest-stable-version.sh scripts/next-semver.sh scripts/test-release-contract.sh
sh scripts/test-release-contract.sh
```

Expected: `release contract: OK`.

- [ ] **Step 6: Commit the version helpers**

```sh
git add scripts/latest-stable-version.sh scripts/next-semver.sh scripts/test-release-contract.sh
git commit -m "ci: add stable version helpers"
```

---

### Task 3: Extract release ordering and retry policy

**Files:**
- Modify: `scripts/test-release-contract.sh`
- Create: `scripts/plan-release.sh`

**Interfaces:**
- Invocation: `sh scripts/plan-release.sh TARGET_SHA TARGET_BUMP STATE_FILE`.
- `STATE_FILE` contains tab-separated records in these exact forms:

  ```text
  pr<TAB>NUMBER<TAB>MERGE_SHA<TAB>none|major|minor|patch
  tag<TAB>X.Y.Z<TAB>SHA
  release<TAB>X.Y.Z<TAB>published|missing|draft|prerelease
  ```

- The script uses `git merge-base --is-ancestor` in the current full-history checkout.
- Stdout always contains `action=`, `previous=`, `version=`, and `blocker_pr=`. Valid actions are `noop`, `wait`, `resume`, and `create`. Inconsistent state exits nonzero.

- [ ] **Step 1: Add a temporary Git graph and complete failing planner fixtures**

Extend `scripts/test-release-contract.sh` before its final failure block with
these exact helpers and graph setup:

```sh
planner_root=$(mktemp -d)
project_root=$(pwd)
planner_state="$planner_root/release-state.tsv"
planner_error="$planner_root/planner-error.txt"
git -C "$planner_root" init -q
git -C "$planner_root" config user.name 'Release Contract'
git -C "$planner_root" config user.email 'release-contract@example.invalid'

for name in baseline patch minor head; do
    printf '%s\n' "$name" >"$planner_root/state"
    git -C "$planner_root" add state
    git -C "$planner_root" commit -q -m "$name"
    commit_sha=$(git -C "$planner_root" rev-parse HEAD)
    case "$name" in
        baseline) baseline_sha=$commit_sha ;;
        patch) patch_sha=$commit_sha ;;
        minor) minor_sha=$commit_sha ;;
        head) head_sha=$commit_sha ;;
    esac
done
main_branch=$(git -C "$planner_root" symbolic-ref --short HEAD)
git -C "$planner_root" checkout -q -b divergent "$baseline_sha"
printf '%s\n' divergent >"$planner_root/divergent"
git -C "$planner_root" add divergent
git -C "$planner_root" commit -q -m divergent
divergent_sha=$(git -C "$planner_root" rev-parse HEAD)
git -C "$planner_root" checkout -q "$main_branch"

pr_row() { printf 'pr\t%s\t%s\t%s' "$1" "$2" "$3"; }
tag_row() { printf 'tag\t%s\t%s' "$1" "$2"; }
release_row() { printf 'release\t%s\t%s' "$1" "$2"; }
write_planner_state() {
    : >"$planner_state"
    for planner_row do
        printf '%s\n' "$planner_row" >>"$planner_state"
    done
}
assert_plan() {
    description=$1
    target=$2
    bump=$3
    expected=$4
    if actual=$(cd "$planner_root" && \
        sh "$project_root/scripts/plan-release.sh" "$target" "$bump" "$planner_state" \
        2>"$planner_error"); then
        assert_equal "$description" "$expected" "$actual"
    else
        fail "$description: planner failed unexpectedly"
    fi
}
assert_plan_failure() {
    description=$1
    target=$2
    bump=$3
    if (cd "$planner_root" && \
        sh "$project_root/scripts/plan-release.sh" "$target" "$bump" "$planner_state") \
        >/dev/null 2>"$planner_error"; then
        fail "$description: expected planner failure"
    fi
}
```

Add exact action fixtures:

```sh
write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" \
    "$(release_row 0.2.0 published)"
assert_plan 'create from baseline' "$patch_sha" patch 'action=create
previous=0.2.0
version=0.2.1
blocker_pr='

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" \
    "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$patch_sha")" \
    "$(release_row 0.2.1 published)" \
    "$(tag_row 0.3.0 "$minor_sha")" \
    "$(release_row 0.3.0 published)"
assert_plan 'completed old rerun' "$patch_sha" patch 'action=noop
previous=0.2.0
version=0.2.1
blocker_pr='

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" \
    "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$patch_sha")" \
    "$(release_row 0.2.1 missing)"
assert_plan 'resume partial target' "$patch_sha" patch 'action=resume
previous=0.2.0
version=0.2.1
blocker_pr='

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(pr_row 11 "$minor_sha" minor)" \
    "$(tag_row 0.2.0 "$baseline_sha")" \
    "$(release_row 0.2.0 published)"
assert_plan 'wait for untagged predecessor' "$minor_sha" minor 'action=wait
previous=0.2.0
version=0.2.1
blocker_pr=10'

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(pr_row 11 "$minor_sha" minor)" \
    "$(tag_row 0.2.0 "$baseline_sha")" \
    "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$patch_sha")" \
    "$(release_row 0.2.1 missing)"
assert_plan 'wait for partial predecessor' "$minor_sha" minor 'action=wait
previous=0.2.0
version=0.2.1
blocker_pr=10'
```

Add refreshed-predecessor fixtures:

```sh
write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(pr_row 11 "$minor_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" \
    "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$patch_sha")" \
    "$(release_row 0.2.1 published)"
assert_plan 'patch after refreshed patch' "$minor_sha" patch 'action=create
previous=0.2.1
version=0.2.2
blocker_pr='

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(pr_row 11 "$minor_sha" minor)" \
    "$(tag_row 0.2.0 "$baseline_sha")" \
    "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$patch_sha")" \
    "$(release_row 0.2.1 published)"
assert_plan 'minor after refreshed patch' "$minor_sha" minor 'action=create
previous=0.2.1
version=0.3.0
blocker_pr='

write_planner_state \
    "$(pr_row 10 "$patch_sha" major)" \
    "$(pr_row 11 "$minor_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" \
    "$(release_row 0.2.0 published)" \
    "$(tag_row 1.0.0 "$patch_sha")" \
    "$(release_row 1.0.0 published)"
assert_plan 'patch after refreshed major' "$minor_sha" patch 'action=create
previous=1.0.0
version=1.0.1
blocker_pr='
```

Add these exact failure fixtures:

```sh
write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$patch_sha")" "$(release_row 0.2.1 published)" \
    "$(tag_row 0.2.2 "$patch_sha")" "$(release_row 0.2.2 published)"
assert_plan_failure 'multiple target tags' "$patch_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)" \
    "$(tag_row 0.3.0 "$patch_sha")" "$(release_row 0.3.0 published)"
assert_plan_failure 'target tag has wrong bump' "$patch_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$minor_sha")" "$(release_row 0.2.1 missing)"
assert_plan_failure 'candidate belongs to another SHA' "$patch_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 missing)"
assert_plan_failure 'missing published predecessor' "$patch_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$divergent_sha")" "$(release_row 0.2.1 missing)"
assert_plan_failure 'divergent stable tag' "$patch_sha" patch

write_planner_state \
    "$(pr_row 12 "$head_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$patch_sha")" "$(release_row 0.2.1 missing)" \
    "$(tag_row 0.3.0 "$minor_sha")" "$(release_row 0.3.0 published)"
assert_plan_failure 'partial tag behind later release' "$head_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" "$(pr_row 10 "$minor_sha" minor)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)"
assert_plan_failure 'duplicate PR number' "$minor_sha" minor

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" \
    "$(release_row 0.2.0 published)" "$(release_row 0.2.0 published)"
assert_plan_failure 'duplicate Release row' "$patch_sha" patch

write_planner_state \
    "$(printf 'pr\t10\t%s\tpatch\textra' "$patch_sha")" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)"
assert_plan_failure 'malformed TSV' "$patch_sha" patch

missing_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
write_planner_state \
    "$(pr_row 9 "$missing_sha" none)" "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)"
assert_plan_failure 'missing PR commit object' "$patch_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)" \
    "$(tag_row 0.2.1 "$missing_sha")" "$(release_row 0.2.1 missing)"
assert_plan_failure 'missing tag commit object' "$patch_sha" patch
```

- [ ] **Step 2: Run planner tests to verify RED**

Run `sh scripts/test-release-contract.sh`.

Expected: nonzero exit because `scripts/plan-release.sh` is absent.

- [ ] **Step 3: Implement the complete planner behind the fixtures**

Create `scripts/plan-release.sh` as one POSIX shell program with these concrete
phases:

1. require exactly three arguments, a full lowercase 40-character target SHA,
   `major|minor|patch`, and a readable regular state file;
2. normalize records into three `mktemp` files and validate exact field counts,
   strict versions, numeric PR numbers, full SHAs, and commit objects with
   `git cat-file -e "$sha^{commit}"`;
3. reject duplicate PR numbers/SHAs, tag versions/SHAs, Release versions,
   missing tag/Release pairs, draft/prerelease states, and a target PR whose
   recorded bump differs from `TARGET_BUMP`;
4. wrap every ancestry query with this tri-state helper:

   ```sh
   is_ancestor() {
       if git merge-base --is-ancestor "$1" "$2" >/dev/null 2>&1; then
           return 0
       else
           ancestry_status=$?
       fi
       [ "$ancestry_status" -eq 1 ] && return 1
       fail_state "cannot compare ancestry: $1 -> $2"
   }
   ```

5. require every stable tag to be comparable with `TARGET_SHA`; for any two
   tag SHAs on the lineage, call `latest-stable-version.sh` on their two
   versions and require the descendant to be the numeric maximum;
6. reject any `missing` tag that has a later published descendant;
7. select the numeric maximum published strict-ancestor tag as predecessor;
8. walk `git rev-list --reverse --ancestry-path
   "$predecessor_sha..$target_sha"`, map each commit to at most one PR and tag,
   and use `next-semver.sh` to advance a rolling predecessor. Emit `wait`
   immediately for the first earlier qualifying PR with no tag or a matching
   `missing` tag; reject tags on direct/unlabeled commits or wrong versions;
9. compute the target version and emit `create`, `resume`, or `noop` using the
   exact four-line output contract. `resume` requires the target tag to be the
   global numeric maximum; `noop` alone may coexist with newer published
   descendant tags; `create` rejects any descendant tag or candidate owned by
   another SHA.

Use `trap cleanup 0 1 2 15` to remove only the exact files returned by
`mktemp`. The planner may use standard `awk`, `grep`, and Git, but every SemVer
parse/increment/max operation must delegate to the two Task 2 helpers.

Use this complete source, keeping diagnostics on stderr and the four output
keys on stdout:

```sh
#!/bin/sh

set -eu

fail_state() { printf '%s\n' "release plan: $1" >&2; exit 1; }
validate_sha() {
    case "$1" in *[!0-9a-f]*|'') fail_state "$2 is not a lowercase SHA" ;; esac
    [ "${#1}" -eq 40 ] || fail_state "$2 is not full length"
}
require_commit() {
    git cat-file -e "$1^{commit}" >/dev/null 2>&1 || fail_state "$2 is not a commit: $1"
}
is_ancestor() {
    if git merge-base --is-ancestor "$1" "$2" >/dev/null 2>&1; then
        return 0
    else
        ancestry_status=$?
    fi
    [ "$ancestry_status" -eq 1 ] && return 1
    fail_state "cannot compare ancestry: $1 -> $2"
}
strict_version() {
    printf '%s\n' "$1" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
}
release_state_for() {
    awk -F '\t' -v version="$1" '$1 == version { print $2 }' "$release_file"
}
tag_sha_for() {
    awk -F '\t' -v version="$1" '$1 == version { print $2 }' "$tag_file"
}
tag_version_at_sha() {
    awk -F '\t' -v sha="$1" '$2 == sha { print $1 }' "$tag_file"
}
emit_plan() {
    printf 'action=%s\nprevious=%s\nversion=%s\nblocker_pr=%s\n' "$1" "$2" "$3" "$4"
}
assert_unique() {
    duplicate=$(awk -F '\t' -v field="$2" '
        { value = $field; seen[value] += 1 }
        END { for (value in seen) if (seen[value] > 1) { print value; exit } }
    ' "$1")
    [ -z "$duplicate" ] || fail_state "duplicate $3: $duplicate"
}

[ "$#" -eq 3 ] || { printf '%s\n' 'usage: plan-release.sh TARGET_SHA TARGET_BUMP STATE_FILE' >&2; exit 2; }
target_sha=$1
target_bump=$2
state_file=$3
validate_sha "$target_sha" TARGET_SHA
require_commit "$target_sha" TARGET_SHA
case "$target_bump" in major|minor|patch) ;; *) fail_state "unsupported target bump: $target_bump" ;; esac
[ -f "$state_file" ] && [ -r "$state_file" ] || fail_state "state file is not readable: $state_file"

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
planner_tmp_root=${TMPDIR:-/tmp}
pr_file=$(mktemp "$planner_tmp_root/release-plan-pr.XXXXXX")
tag_file=$(mktemp "$planner_tmp_root/release-plan-tag.XXXXXX")
release_file=$(mktemp "$planner_tmp_root/release-plan-release.XXXXXX")
ancestor_versions_file=$(mktemp "$planner_tmp_root/release-plan-ancestor.XXXXXX")
commit_file=$(mktemp "$planner_tmp_root/release-plan-commits.XXXXXX")
all_versions_file=$(mktemp "$planner_tmp_root/release-plan-versions.XXXXXX")
cleanup() {
    rm -f "$pr_file" "$tag_file" "$release_file" \
        "$ancestor_versions_file" "$commit_file" "$all_versions_file"
}
trap cleanup 0 1 2 15

tab=$(printf '\t')
line_number=0
while IFS="$tab" read -r kind one two three extra || \
    [ -n "${kind:-}${one:-}${two:-}${three:-}${extra:-}" ]; do
    line_number=$((line_number + 1))
    [ -z "${extra:-}" ] || fail_state "extra field at line $line_number"
    case "${kind:-}" in
        pr)
            [ -n "${one:-}" ] && [ -n "${two:-}" ] && [ -n "${three:-}" ] || \
                fail_state "malformed pr record at line $line_number"
            case "$one" in *[!0-9]*|'') fail_state "invalid PR number at line $line_number" ;; esac
            validate_sha "$two" "PR SHA at line $line_number"
            require_commit "$two" "PR SHA at line $line_number"
            case "$three" in none|major|minor|patch) ;; *) fail_state "invalid PR bump at line $line_number" ;; esac
            printf '%s\t%s\t%s\n' "$one" "$two" "$three" >>"$pr_file"
            ;;
        tag)
            [ -n "${one:-}" ] && [ -n "${two:-}" ] && [ -z "${three:-}" ] || \
                fail_state "malformed tag record at line $line_number"
            strict_version "$one" || fail_state "invalid stable tag at line $line_number: $one"
            validate_sha "$two" "tag SHA at line $line_number"
            require_commit "$two" "tag SHA at line $line_number"
            printf '%s\t%s\n' "$one" "$two" >>"$tag_file"
            ;;
        release)
            [ -n "${one:-}" ] && [ -n "${two:-}" ] && [ -z "${three:-}" ] || \
                fail_state "malformed release record at line $line_number"
            strict_version "$one" || fail_state "invalid Release version at line $line_number: $one"
            case "$two" in published|missing|draft|prerelease) ;; *) fail_state "invalid Release state at line $line_number" ;; esac
            printf '%s\t%s\n' "$one" "$two" >>"$release_file"
            ;;
        *) fail_state "unknown record at line $line_number" ;;
    esac
done <"$state_file"

assert_unique "$pr_file" 1 'PR number'
assert_unique "$pr_file" 2 'PR SHA'
assert_unique "$tag_file" 1 'tag version'
assert_unique "$tag_file" 2 'tag SHA'
assert_unique "$release_file" 1 'Release version'

while IFS="$tab" read -r version tag_sha; do
    [ -n "$(release_state_for "$version")" ] || fail_state "tag has no Release state: $version"
done <"$tag_file"
while IFS="$tab" read -r version release_state; do
    [ -n "$(tag_sha_for "$version")" ] || fail_state "Release has no tag: $version"
    case "$release_state" in
        draft|prerelease) fail_state "non-stable Release state for $version: $release_state" ;;
    esac
done <"$release_file"

target_pr_count=0
while IFS="$tab" read -r pr_number merge_sha pr_bump; do
    if [ "$merge_sha" = "$target_sha" ]; then
        target_pr_count=$((target_pr_count + 1))
        [ "$pr_bump" = "$target_bump" ] || fail_state "target PR bump does not match TARGET_BUMP"
    elif ! is_ancestor "$merge_sha" "$target_sha"; then
        fail_state "PR is not an ancestor of target: $pr_number"
    fi
done <"$pr_file"
[ "$target_pr_count" -eq 1 ] || fail_state "expected one target PR record"

while IFS="$tab" read -r left_version left_sha <&3; do
    if is_ancestor "$left_sha" "$target_sha"; then
        :
    elif is_ancestor "$target_sha" "$left_sha"; then
        :
    else
        fail_state "stable tag is on a divergent lineage: $left_version"
    fi

    while IFS="$tab" read -r right_version right_sha <&4; do
        [ "$left_version" != "$right_version" ] || continue
        if is_ancestor "$left_sha" "$right_sha"; then
            later_version=$right_version
        elif is_ancestor "$right_sha" "$left_sha"; then
            later_version=$left_version
        else
            fail_state "stable tags are on divergent lineages: $left_version and $right_version"
        fi
        numeric_max=$(printf '%s\n%s\n' "$left_version" "$right_version" | \
            sh "$script_dir/latest-stable-version.sh")
        [ "$numeric_max" = "$later_version" ] || \
            fail_state "stable versions do not increase with ancestry"
    done 4<"$tag_file"
done 3<"$tag_file"

while IFS="$tab" read -r partial_version partial_sha; do
    [ "$(release_state_for "$partial_version")" = missing ] || continue
    while IFS="$tab" read -r published_version published_sha; do
        [ "$(release_state_for "$published_version")" = published ] || continue
        [ "$partial_sha" != "$published_sha" ] || continue
        if is_ancestor "$partial_sha" "$published_sha"; then
            fail_state "partial tag is behind published release: $partial_version"
        fi
    done <"$tag_file"
done <"$tag_file"

: >"$ancestor_versions_file"
while IFS="$tab" read -r version tag_sha; do
    [ "$tag_sha" != "$target_sha" ] || continue
    is_ancestor "$tag_sha" "$target_sha" || continue
    [ "$(release_state_for "$version")" = published ] || continue
    printf '%s\n' "$version" >>"$ancestor_versions_file"
done <"$tag_file"
if predecessor_version=$(sh "$script_dir/latest-stable-version.sh" <"$ancestor_versions_file" 2>/dev/null); then
    :
else
    fail_state 'no published stable predecessor'
fi
predecessor_sha=$(tag_sha_for "$predecessor_version")
[ -n "$predecessor_sha" ] || fail_state "missing predecessor tag: $predecessor_version"

git rev-list --reverse --ancestry-path "$predecessor_sha..$target_sha" \
    >"$commit_file" || fail_state 'cannot enumerate target ancestry'
grep -Fqx "$target_sha" "$commit_file" || fail_state 'target is not after predecessor'

current_version=$predecessor_version
while IFS= read -r commit_sha; do
    [ "$commit_sha" != "$target_sha" ] || continue
    pr_record=$(awk -F '\t' -v sha="$commit_sha" '$2 == sha { print $1 "\t" $3 }' "$pr_file")
    tag_version=$(tag_version_at_sha "$commit_sha")
    if [ -z "$pr_record" ]; then
        [ -z "$tag_version" ] || fail_state "tag is not owned by a merged PR: $tag_version"
        continue
    fi
    pr_number=${pr_record%%"$tab"*}
    pr_bump=${pr_record#*"$tab"}
    if [ "$pr_bump" = none ]; then
        [ -z "$tag_version" ] || fail_state "unlabeled PR owns stable tag: $pr_number"
        continue
    fi

    expected_version=$(sh "$script_dir/next-semver.sh" "$current_version" "$pr_bump")
    if [ -z "$tag_version" ]; then
        emit_plan wait "$current_version" "$expected_version" "$pr_number"
        exit 0
    fi
    [ "$tag_version" = "$expected_version" ] || fail_state "wrong version at PR #$pr_number"
    case "$(release_state_for "$tag_version")" in
        published) current_version=$tag_version ;;
        missing) emit_plan wait "$current_version" "$tag_version" "$pr_number"; exit 0 ;;
        *) fail_state "invalid Release state at PR #$pr_number" ;;
    esac
done <"$commit_file"

expected_target_version=$(sh "$script_dir/next-semver.sh" "$current_version" "$target_bump")
target_tag=$(tag_version_at_sha "$target_sha")
if [ -n "$target_tag" ]; then
    [ "$target_tag" = "$expected_target_version" ] || fail_state 'target tag does not match approved bump'
    case "$(release_state_for "$target_tag")" in
        published) emit_plan noop "$current_version" "$target_tag" ''; exit 0 ;;
        missing)
            awk -F '\t' '{ print $1 }' "$tag_file" >"$all_versions_file"
            highest_version=$(sh "$script_dir/latest-stable-version.sh" <"$all_versions_file")
            [ "$highest_version" = "$target_tag" ] || fail_state 'partial target is not the highest stable tag'
            emit_plan resume "$current_version" "$target_tag" ''
            exit 0
            ;;
        *) fail_state 'target Release is not stable' ;;
    esac
fi

while IFS="$tab" read -r version tag_sha; do
    [ "$tag_sha" != "$target_sha" ] || continue
    if is_ancestor "$target_sha" "$tag_sha"; then
        fail_state "cannot create release before descendant tag: $version"
    fi
done <"$tag_file"
candidate_sha=$(tag_sha_for "$expected_target_version")
[ -z "$candidate_sha" ] || fail_state "candidate version already belongs to $candidate_sha"
emit_plan create "$current_version" "$expected_target_version" ''
```

- [ ] **Step 4: Verify planner syntax and all fixtures**

```sh
sh -n scripts/plan-release.sh scripts/test-release-contract.sh
sh scripts/test-release-contract.sh
```

Expected: `release contract: OK` with planner coverage for `noop`, `wait`,
`resume`, `create`, and all inconsistent states.

- [ ] **Step 5: Commit the planner**

```sh
git add scripts/plan-release.sh scripts/test-release-contract.sh
git commit -m "ci: add deterministic release planner"
```

---

### Task 4: Consolidate the read-only CI gate

**Files:**
- Modify: `scripts/test-release-contract.sh`
- Create: `scripts/test-fixtures/fake-gh.sh`
- Create: `scripts/release-context-for-sha.sh`
- Create: `.github/workflows/ci.yml`
- Delete: `.github/workflows/build.yml`
- Delete: `.github/workflows/test.yml`
- Delete: `.github/workflows/gitlint.yml`

**Interfaces:**
- `release-context-for-sha.sh REPOSITORY SHA` prints `pr_number=`, `merge_sha=`, and `bump=`. Zero associated merged PRs is a valid empty context; one exact PR is reconstructed; multiple exact PRs, incomplete pagination, missing merge boundary, or a merge SHA mismatch fail.
- The `CI` workflow exposes required check names `release-label` and `build-and-test`.

- [ ] **Step 1: Add offline adapter fixtures before the adapter exists**

Create `scripts/test-fixtures/fake-gh.sh` with an endpoint-aware fake. It must
return GitHub API `--paginate --slurp` shapes, including more than one page:

```sh
#!/bin/sh

set -eu

: "${FAKE_GH_SCENARIO:?FAKE_GH_SCENARIO is required}"
: "${FAKE_TARGET_SHA:?FAKE_TARGET_SHA is required}"

endpoint=
for argument do
    case "$argument" in
        repos/*) endpoint=$argument ;;
    esac
done
[ -n "$endpoint" ] || { printf '%s\n' 'fake gh: missing endpoint' >&2; exit 2; }

case "$endpoint" in
    */pulls\?per_page=100)
        case "$FAKE_GH_SCENARIO" in
            association_failure) exit 1 ;;
            zero)
                printf '%s\n' '[[{"number":40,"merged_at":null,"base":{"ref":"main"},"merge_commit_sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},{"number":41,"merged_at":"2026-08-08T10:00:00Z","base":{"ref":"other"},"merge_commit_sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}],[]]'
                ;;
            multiple)
                printf '[[{"number":42,"merged_at":"2026-08-08T10:00:00Z","base":{"ref":"main"},"merge_commit_sha":"%s"}],[{"number":43,"merged_at":"2026-08-08T10:01:00Z","base":{"ref":"main"},"merge_commit_sha":"%s"}]]\n' "$FAKE_TARGET_SHA" "$FAKE_TARGET_SHA"
                ;;
            mismatch)
                printf '%s\n' '[[{"number":42,"merged_at":"2026-08-08T10:00:00Z","base":{"ref":"main"},"merge_commit_sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]]'
                ;;
            one|missing_merge|multiple_merge|timeline_failure)
                printf '[[{"number":42,"merged_at":"2026-08-08T10:00:00Z","base":{"ref":"main"},"merge_commit_sha":"%s"}],[]]\n' "$FAKE_TARGET_SHA"
                ;;
            *) printf '%s\n' "fake gh: unknown scenario: $FAKE_GH_SCENARIO" >&2; exit 2 ;;
        esac
        ;;
    */issues/42/timeline\?per_page=100)
        case "$FAKE_GH_SCENARIO" in
            timeline_failure) exit 1 ;;
            missing_merge)
                printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}}],[]]'
                ;;
            multiple_merge)
                printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}},{"event":"merged"}],[{"event":"merged"}]]'
                ;;
            one)
                printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}}],[{"event":"merged"},{"event":"unlabeled","label":{"name":"semver:patch"}}]]'
                ;;
            *) printf '%s\n' 'fake gh: unexpected timeline request' >&2; exit 2 ;;
        esac
        ;;
    *) printf '%s\n' "fake gh: unexpected endpoint: $endpoint" >&2; exit 2 ;;
esac
```

Mark the fixture executable with
`chmod +x scripts/test-fixtures/fake-gh.sh`; it is invoked directly through
`GH_BIN`.

Append these assertions before the final failure block in
`scripts/test-release-contract.sh`:

```sh
adapter_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
fake_gh=scripts/test-fixtures/fake-gh.sh

adapter_output=$(env FAKE_GH_SCENARIO=zero FAKE_TARGET_SHA="$adapter_sha" \
    GH_BIN="$fake_gh" sh scripts/release-context-for-sha.sh owner/repository "$adapter_sha")
assert_equal 'zero eligible associated PRs' 'pr_number=
merge_sha=
bump=' "$adapter_output"

adapter_output=$(env FAKE_GH_SCENARIO=one FAKE_TARGET_SHA="$adapter_sha" \
    GH_BIN="$fake_gh" sh scripts/release-context-for-sha.sh owner/repository "$adapter_sha")
assert_equal 'one exact PR with paginated timeline' "pr_number=42
merge_sha=$adapter_sha
bump=patch" "$adapter_output"

assert_failure 'multiple exact associated PRs' env FAKE_GH_SCENARIO=multiple \
    FAKE_TARGET_SHA="$adapter_sha" GH_BIN="$fake_gh" \
    sh scripts/release-context-for-sha.sh owner/repository "$adapter_sha"
assert_failure 'merge SHA association mismatch' env FAKE_GH_SCENARIO=mismatch \
    FAKE_TARGET_SHA="$adapter_sha" GH_BIN="$fake_gh" \
    sh scripts/release-context-for-sha.sh owner/repository "$adapter_sha"
assert_failure 'missing merge timeline event' env FAKE_GH_SCENARIO=missing_merge \
    FAKE_TARGET_SHA="$adapter_sha" GH_BIN="$fake_gh" \
    sh scripts/release-context-for-sha.sh owner/repository "$adapter_sha"
assert_failure 'multiple merge timeline events' env FAKE_GH_SCENARIO=multiple_merge \
    FAKE_TARGET_SHA="$adapter_sha" GH_BIN="$fake_gh" \
    sh scripts/release-context-for-sha.sh owner/repository "$adapter_sha"
assert_failure 'association API failure' env FAKE_GH_SCENARIO=association_failure \
    FAKE_TARGET_SHA="$adapter_sha" GH_BIN="$fake_gh" \
    sh scripts/release-context-for-sha.sh owner/repository "$adapter_sha"
assert_failure 'timeline API failure' env FAKE_GH_SCENARIO=timeline_failure \
    FAKE_TARGET_SHA="$adapter_sha" GH_BIN="$fake_gh" \
    sh scripts/release-context-for-sha.sh owner/repository "$adapter_sha"
```

- [ ] **Step 2: Run adapter tests to verify RED**

```sh
sh scripts/test-release-contract.sh
```

Expected: nonzero exit because `scripts/release-context-for-sha.sh` is absent.

- [ ] **Step 3: Implement the read-only GitHub context adapter**

Use `${GH_BIN:-gh}` and `${JQ_BIN:-jq}` so tests can inject fakes. Create the
adapter with this complete source:

```sh
#!/bin/sh

set -eu

[ "$#" -eq 2 ] || { printf '%s\n' 'usage: release-context-for-sha.sh REPOSITORY SHA' >&2; exit 2; }
repository=$1
target_sha=$2
case "$repository" in */*) ;; *) printf '%s\n' 'release context: invalid repository' >&2; exit 1 ;; esac
case "$target_sha" in *[!0-9a-f]*|'') printf '%s\n' 'release context: invalid SHA' >&2; exit 1 ;; esac
[ "${#target_sha}" -eq 40 ] || { printf '%s\n' 'release context: SHA must be full length' >&2; exit 1; }

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
GH_BIN=${GH_BIN:-gh}
JQ_BIN=${JQ_BIN:-jq}
command -v "$GH_BIN" >/dev/null 2>&1 || { printf '%s\n' "release context: missing tool: $GH_BIN" >&2; exit 1; }
command -v "$JQ_BIN" >/dev/null 2>&1 || { printf '%s\n' "release context: missing tool: $JQ_BIN" >&2; exit 1; }
pulls_json=$("$GH_BIN" api --paginate --slurp \
    -H 'Accept: application/vnd.github+json' \
    "repos/$repository/commits/$target_sha/pulls?per_page=100")
candidates=$("$JQ_BIN" -c \
    '[add[] | select(.merged_at != null and .base.ref == "main")]' \
    <<EOF
$pulls_json
EOF
)
matching=$("$JQ_BIN" -c --arg sha "$target_sha" \
    '[.[] | select(.merge_commit_sha == $sha)]' \
    <<EOF
$candidates
EOF
)

candidate_count=$(printf '%s\n' "$candidates" | "$JQ_BIN" -r 'length')
matching_count=$(printf '%s\n' "$matching" | "$JQ_BIN" -r 'length')
if [ "$candidate_count" -eq 0 ]; then
    printf 'pr_number=\nmerge_sha=\nbump=\n'
    exit 0
fi
[ "$matching_count" -ne 0 ] || {
    printf '%s\n' 'release context: associated main PR does not own target SHA' >&2
    exit 1
}
[ "$matching_count" -eq 1 ] || {
    printf '%s\n' 'release context: multiple PRs own target SHA' >&2
    exit 1
}

pr_number=$(printf '%s\n' "$matching" | "$JQ_BIN" -r '.[0].number')
merge_sha=$(printf '%s\n' "$matching" | "$JQ_BIN" -r '.[0].merge_commit_sha')
case "$pr_number" in *[!0-9]*|'') printf '%s\n' 'release context: invalid PR number' >&2; exit 1 ;; esac
[ "$merge_sha" = "$target_sha" ] || { printf '%s\n' 'release context: merge SHA mismatch' >&2; exit 1; }

timeline_json=$("$GH_BIN" api --paginate --slurp \
    -H 'Accept: application/vnd.github+json' \
    "repos/$repository/issues/$pr_number/timeline?per_page=100")
events=$(printf '%s\n' "$timeline_json" | "$JQ_BIN" -r '
  add[] |
  if .event == "labeled" then ["labeled", .label.name] | @tsv
  elif .event == "unlabeled" then ["unlabeled", .label.name] | @tsv
  elif .event == "merged" then "merged"
  else empty
  end
')
labels=$(printf '%s\n' "$events" | sh "$script_dir/release-labels-at-merge.sh")
bump=$(printf '%s\n' "$labels" | sh "$script_dir/validate-release-labels.sh")
printf 'pr_number=%s\nmerge_sha=%s\nbump=%s\n' "$pr_number" "$merge_sha" "$bump"
```

Every API and policy stage is captured separately under `set -eu`, so a failed
page, normalization, merge-boundary replay, or label validation cannot be
masked by a downstream command.

- [ ] **Step 4: Create the CI workflow**

Create `.github/workflows/ci.yml` with this complete job boundary:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened, labeled, unlabeled]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.event.pull_request.number || github.run_id }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  release-label:
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      issues: read
      pull-requests: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
        with:
          persist-credentials: false
      - name: Record policy tools
        shell: bash
        run: |
          git --version
          gh --version
          jq --version
      - name: Validate pull request release labels
        if: github.event_name == 'pull_request'
        shell: bash
        run: |
          set -o pipefail
          jq -r '.pull_request.labels[].name' "$GITHUB_EVENT_PATH" | sh scripts/validate-release-labels.sh
      - name: Validate merged pull request release labels
        if: github.event_name == 'push'
        shell: bash
        env:
          GH_TOKEN: ${{ github.token }}
        run: sh scripts/release-context-for-sha.sh "$GITHUB_REPOSITORY" "$GITHUB_SHA"

  build-and-test:
    runs-on: macos-15
    steps:
      - name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
        with:
          persist-credentials: false
      - name: Record toolchain
        run: |
          sw_vers
          xcodebuild -version
          swift --version
          xcbeautify --version
          git --version
          jq --version
      - name: Validate documentation contract
        run: sh scripts/validate-documentation.sh
      - name: Validate release contract
        run: sh scripts/test-release-contract.sh
      - name: Build package and tests
        shell: bash
        run: |
          set -o pipefail
          swift build --build-tests 2>&1 | xcbeautify --renderer github-actions
      - name: Run prebuilt tests
        shell: bash
        run: |
          set -o pipefail
          swift test --skip-build 2>&1 | xcbeautify --renderer github-actions --is-ci
```

- [ ] **Step 5: Remove the obsolete workflow files by exact path**

```sh
git rm .github/workflows/build.yml
git rm .github/workflows/test.yml
git rm .github/workflows/gitlint.yml
```

Do not remove or modify `.gitlint`.

- [ ] **Step 6: Verify syntax and the CI trust boundary**

```sh
sh -n scripts/test-fixtures/fake-gh.sh scripts/release-context-for-sha.sh scripts/test-release-contract.sh
sh scripts/test-release-contract.sh
actionlint .github/workflows/ci.yml
! grep -Fq 'contents: write' .github/workflows/ci.yml
! test -e .github/workflows/build.yml
! test -e .github/workflows/test.yml
! test -e .github/workflows/gitlint.yml
test -f .gitlint
```

Expected: every command exits zero.

- [ ] **Step 7: Commit the consolidated CI**

```sh
git add scripts/release-context-for-sha.sh scripts/test-fixtures/fake-gh.sh scripts/test-release-contract.sh .github/workflows/ci.yml
git commit -m "ci: consolidate build and test checks"
```

---

### Task 5: Add trusted, idempotent publication

**Files:**
- Create: `scripts/publish-release.sh`
- Create: `scripts/test-publish-release.sh`
- Create: `scripts/test-fixtures/fake-release-gh.sh`
- Create: `scripts/test-fixtures/fake-release-sleep.sh`
- Create: `.github/workflows/release.yml`
- Create: `.github/release.yml`
- Modify: `scripts/test-release-contract.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- `publish-release.sh REPOSITORY TARGET_SHA` requires `GH_TOKEN`, a full Git checkout, `gh`, `jq`, and the pure policy scripts. It performs no mutation for an empty bump and never updates or deletes existing refs or Releases.
- Publisher tests replace `gh` and `sleep`, use a disposable local bare Git remote, and never contact GitHub or mutate repository state outside their `mktemp` root.
- `.github/workflows/release.yml` runs only after successful push CI on `main` and grants `contents: write` only to its release job.

- [ ] **Step 1: Add publication-state assertions before network code**

Extend planner fixtures to prove all of these outcomes:

```text
target tag + published Release + newer Release = noop
target tag + missing Release + no newer Release = resume
target tag + missing Release + newer Release = failure
orphaned partial tag behind a later published baseline = failure
candidate version already points to another SHA = failure
earlier unlabeled PR = ignored
earlier labeled PR without a published Release = wait
earlier partial tag without a Release = wait
fresh predecessor state changes the next version before create
```

Run `sh scripts/test-release-contract.sh` and require `release contract: OK`.

- [ ] **Step 2: Add offline publisher fakes and behavioral tests**

Create `scripts/test-fixtures/fake-release-gh.sh`. It receives
`FAKE_RELEASE_SCENARIO`, `FAKE_RELEASE_STATE_DIR`, `FAKE_GIT_REPO`,
`FAKE_BASELINE_SHA`, `FAKE_EARLIER_SHA`, and `FAKE_TARGET_SHA`. Parse the API
endpoint plus every `-f key=value` argument and implement this exact protocol:

| Request | Fake response or effect |
| --- | --- |
| `commits/<target>/pulls` | PR `#20`, merged to `main`, exact target SHA |
| `commits/<earlier>/pulls` | PR `#10`, merged to `main`, exact earlier SHA |
| `issues/20/timeline` | `merged` only for `no_label`; otherwise target label then `merged` |
| `issues/10/timeline` | `semver:patch` then `merged` |
| closed `pulls` | target only; earlier + target for `wait_refresh`; invalid missing-object row + target for `bad_merge_sha` |
| `releases` GET | one slurped page built from newline versions in `$FAKE_RELEASE_STATE_DIR/published.txt` |
| `git/refs` POST | append `ref<TAB>VERSION<TAB>SHA` to `mutations.tsv`, create/push the lightweight tag in the disposable repository, then succeed |
| `git/ref/tags/<version>` GET | print the exact commit SHA for the lightweight local tag |
| `generate-notes` POST | print `{"body":"generated notes"}` |
| `releases` POST | append `release<TAB>VERSION` to `mutations.tsv` and append the version to `published.txt` |

Scenario overrides are exact: `conflict_422` creates/pushes the tag, prints
`gh: Reference already exists (HTTP 422)` to stderr, and exits 1 from the ref
POST; `non_422` prints `gh: Internal Server Error (HTTP 500)` and exits 1
without creating a tag; `release_failure_once` fails the first Release POST,
creates `$FAKE_RELEASE_STATE_DIR/release-failed-once`, and succeeds on the next
invocation; `bad_merge_sha` returns
`bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb` for PR `#10`.

Use this endpoint dispatcher in the fake so unexpected calls fail instead of
silently succeeding:

```sh
#!/bin/sh

set -eu
: "${FAKE_RELEASE_SCENARIO:?}"
: "${FAKE_RELEASE_STATE_DIR:?}"
: "${FAKE_GIT_REPO:?}"
: "${FAKE_BASELINE_SHA:?}"
: "${FAKE_EARLIER_SHA:?}"
: "${FAKE_TARGET_SHA:?}"

method=GET
endpoint=
ref=
sha=
tag_name=
while [ "$#" -gt 0 ]; do
    case "$1" in
        api|--paginate|--slurp) shift ;;
        -H|--jq) shift 2 ;;
        --method) method=$2; shift 2 ;;
        -f|-F)
            assignment=$2
            key=${assignment%%=*}
            value=${assignment#*=}
            case "$key" in
                ref) ref=$value ;;
                sha) sha=$value ;;
                tag_name) tag_name=$value ;;
            esac
            shift 2
            ;;
        repos/*) endpoint=$1; shift ;;
        *) printf '%s\n' "fake release gh: unexpected argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$endpoint" ] || { printf '%s\n' 'fake release gh: missing endpoint' >&2; exit 2; }

print_pr() {
    printf '{"number":%s,"merged_at":"2026-08-08T10:00:00Z","base":{"ref":"main"},"merge_commit_sha":"%s"}' "$1" "$2"
}
create_lightweight_tag() {
    version=$1
    commit_sha=$2
    if ! git -C "$FAKE_GIT_REPO" rev-parse -q --verify "refs/tags/$version" >/dev/null; then
        git -C "$FAKE_GIT_REPO" tag "$version" "$commit_sha"
        git -C "$FAKE_GIT_REPO" push -q origin "refs/tags/$version"
    fi
}
print_releases() {
    jq -Rn '[inputs | select(length > 0) | {tag_name: ., draft: false, prerelease: false}]' \
        <"$FAKE_RELEASE_STATE_DIR/published.txt" | jq -s '.'
}

case "$method:$endpoint" in
    GET:*/commits/*/pulls\?per_page=100)
        commit_sha=${endpoint#*/commits/}
        commit_sha=${commit_sha%%/*}
        case "$commit_sha" in
            "$FAKE_TARGET_SHA") printf '[[%s]]\n' "$(print_pr 20 "$FAKE_TARGET_SHA")" ;;
            "$FAKE_EARLIER_SHA") printf '[[%s]]\n' "$(print_pr 10 "$FAKE_EARLIER_SHA")" ;;
            *) printf '%s\n' '[[]]' ;;
        esac
        ;;
    GET:*/issues/20/timeline\?per_page=100)
        case "$FAKE_RELEASE_SCENARIO" in
            no_label) printf '%s\n' '[[{"event":"merged"}]]' ;;
            wait_refresh) printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:minor"}},{"event":"merged"}]]' ;;
            *) printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}},{"event":"merged"}]]' ;;
        esac
        ;;
    GET:*/issues/10/timeline\?per_page=100)
        printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}},{"event":"merged"}]]'
        ;;
    GET:*/pulls\?state=closed\&base=main\&per_page=100)
        case "$FAKE_RELEASE_SCENARIO" in
            wait_refresh)
                printf '[[%s,%s]]\n' "$(print_pr 10 "$FAKE_EARLIER_SHA")" "$(print_pr 20 "$FAKE_TARGET_SHA")"
                ;;
            bad_merge_sha)
                printf '[[%s,%s]]\n' \
                    "$(print_pr 10 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb)" \
                    "$(print_pr 20 "$FAKE_TARGET_SHA")"
                ;;
            *) printf '[[%s]]\n' "$(print_pr 20 "$FAKE_TARGET_SHA")" ;;
        esac
        ;;
    GET:*/releases\?per_page=100) print_releases ;;
    POST:*/git/refs)
        version=${ref#refs/tags/}
        printf 'ref\t%s\t%s\n' "$version" "$sha" >>"$FAKE_RELEASE_STATE_DIR/mutations.tsv"
        case "$FAKE_RELEASE_SCENARIO" in
            non_422)
                printf '%s\n' 'gh: Internal Server Error (HTTP 500)' >&2
                exit 1
                ;;
            conflict_422)
                create_lightweight_tag "$version" "$sha"
                printf '%s\n' 'gh: Reference already exists (HTTP 422)' >&2
                exit 1
                ;;
        esac
        create_lightweight_tag "$version" "$sha"
        printf '{"ref":"refs/tags/%s","object":{"type":"commit","sha":"%s"}}\n' "$version" "$sha"
        ;;
    GET:*/git/ref/tags/*)
        version=${endpoint##*/}
        git -C "$FAKE_GIT_REPO" rev-parse "refs/tags/$version^{commit}"
        ;;
    POST:*/releases/generate-notes)
        printf '%s\n' '{"body":"generated notes"}'
        ;;
    POST:*/releases)
        printf 'release\t%s\n' "$tag_name" >>"$FAKE_RELEASE_STATE_DIR/mutations.tsv"
        if [ "$FAKE_RELEASE_SCENARIO" = release_failure_once ] && \
            [ ! -e "$FAKE_RELEASE_STATE_DIR/release-failed-once" ]; then
            : >"$FAKE_RELEASE_STATE_DIR/release-failed-once"
            printf '%s\n' 'gh: Internal Server Error (HTTP 500)' >&2
            exit 1
        fi
        grep -Fqx "$tag_name" "$FAKE_RELEASE_STATE_DIR/published.txt" || \
            printf '%s\n' "$tag_name" >>"$FAKE_RELEASE_STATE_DIR/published.txt"
        printf '{"tag_name":"%s","draft":false,"prerelease":false}\n' "$tag_name"
        ;;
    *) printf '%s\n' "fake release gh: unexpected request: $method $endpoint" >&2; exit 2 ;;
esac
```

Create `scripts/test-fixtures/fake-release-sleep.sh` with this exact behavior:

```sh
#!/bin/sh

set -eu
printf 'sleep\t%s\n' "$1" >>"$FAKE_RELEASE_STATE_DIR/mutations.tsv"
if [ "$FAKE_RELEASE_SCENARIO" = wait_refresh ] && \
    [ ! -e "$FAKE_RELEASE_STATE_DIR/wait-refreshed" ]; then
    git -C "$FAKE_GIT_REPO" tag 0.2.1 "$FAKE_EARLIER_SHA"
    git -C "$FAKE_GIT_REPO" push -q origin refs/tags/0.2.1
    printf '%s\n' 0.2.1 >>"$FAKE_RELEASE_STATE_DIR/published.txt"
    : >"$FAKE_RELEASE_STATE_DIR/wait-refreshed"
fi
```

Mark both fakes executable. Create `scripts/test-publish-release.sh` with
`fail`, `assert_success`, `assert_failure`, and `assert_log` helpers. For each
case, `setup_case` must create a new
`mktemp -d`, a bare `origin`, and a work repository with linear `baseline`,
`earlier`, and `target` commits; push `main`; create/push lightweight `0.2.0`
at baseline; initialize `published.txt` with `0.2.0`; and checkout target.
Invoke the publisher only through this exact environment boundary:

```sh
run_publisher() {
    (
        cd "$case_repo"
        env \
          GH_TOKEN=test-token \
          GH_BIN="$project_root/scripts/test-fixtures/fake-release-gh.sh" \
          JQ_BIN=jq \
          SLEEP_BIN="$project_root/scripts/test-fixtures/fake-release-sleep.sh" \
          RELEASE_MAX_ATTEMPTS=3 \
          RELEASE_WAIT_SECONDS=0 \
          FAKE_RELEASE_SCENARIO="$scenario" \
          FAKE_RELEASE_STATE_DIR="$case_state" \
          FAKE_GIT_REPO="$case_repo" \
          FAKE_BASELINE_SHA="$baseline_sha" \
          FAKE_EARLIER_SHA="$earlier_sha" \
          FAKE_TARGET_SHA="$target_sha" \
          sh "$project_root/scripts/publish-release.sh" owner/repository "$target_sha"
    )
}
```

Use this setup and exact scenario assertions around `run_publisher`:

```sh
#!/bin/sh

set -u
failures=0
project_root=$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)
fail() { printf '%s\n' "publisher contract: $1" >&2; failures=$((failures + 1)); }
assert_success() { description=$1; shift; "$@" >/dev/null 2>&1 || fail "$description: expected success"; }
assert_failure() { description=$1; shift; if "$@" >/dev/null 2>&1; then fail "$description: expected failure"; fi; }
assert_log() {
    description=$1
    expected=$2
    actual=$(sed -n '1,$p' "$case_state/mutations.tsv")
    [ "$actual" = "$expected" ] || fail "$description: unexpected mutation log"
}
setup_case() {
    scenario=$1
    case_root=$(mktemp -d)
    case_state="$case_root/state"
    case_repo="$case_root/work"
    case_remote="$case_root/origin.git"
    mkdir "$case_state"
    : >"$case_state/mutations.tsv"
    printf '%s\n' 0.2.0 >"$case_state/published.txt"
    git init -q --bare "$case_remote"
    git init -q -b main "$case_repo"
    git -C "$case_repo" config user.name 'Publisher Contract'
    git -C "$case_repo" config user.email 'publisher-contract@example.invalid'
    git -C "$case_repo" remote add origin "$case_remote"
    for commit_name in baseline earlier target; do
        printf '%s\n' "$commit_name" >"$case_repo/state"
        git -C "$case_repo" add state
        git -C "$case_repo" commit -q -m "$commit_name"
        commit_sha=$(git -C "$case_repo" rev-parse HEAD)
        case "$commit_name" in
            baseline) baseline_sha=$commit_sha ;;
            earlier) earlier_sha=$commit_sha ;;
            target) target_sha=$commit_sha ;;
        esac
    done
    git -C "$case_repo" push -q -u origin main
    git -C "$case_repo" tag 0.2.0 "$baseline_sha"
    git -C "$case_repo" push -q origin refs/tags/0.2.0
}
precreate_target_tag() {
    git -C "$case_repo" tag 0.2.1 "$target_sha"
    git -C "$case_repo" push -q origin refs/tags/0.2.1
}

setup_case no_label
assert_success 'no label' run_publisher
assert_log 'no label' ''

setup_case create
assert_success 'create' run_publisher
expected_log=$(printf 'ref\t0.2.1\t%s\nrelease\t0.2.1' "$target_sha")
assert_log 'create' "$expected_log"

setup_case resume
precreate_target_tag
assert_success 'resume' run_publisher
expected_log=$(printf 'release\t0.2.1')
assert_log 'resume' "$expected_log"

setup_case noop
precreate_target_tag
printf '%s\n' 0.2.1 >>"$case_state/published.txt"
assert_success 'noop' run_publisher
assert_log 'noop' ''

setup_case wait_refresh
assert_success 'wait refresh' run_publisher
expected_log=$(printf 'sleep\t0\nref\t0.3.0\t%s\nrelease\t0.3.0' "$target_sha")
assert_log 'wait refresh' "$expected_log"

setup_case conflict_422
assert_success '422 recovery' run_publisher
expected_log=$(printf 'ref\t0.2.1\t%s\nrelease\t0.2.1' "$target_sha")
assert_log '422 recovery' "$expected_log"

setup_case non_422
assert_failure 'non-422 failure' run_publisher
expected_log=$(printf 'ref\t0.2.1\t%s' "$target_sha")
assert_log 'non-422 failure' "$expected_log"

setup_case release_failure_once
assert_failure 'first Release failure' run_publisher
assert_success 'Release retry' run_publisher
expected_log=$(printf 'ref\t0.2.1\t%s\nrelease\t0.2.1\nrelease\t0.2.1' "$target_sha")
assert_log 'Release retry' "$expected_log"

setup_case bad_merge_sha
assert_failure 'missing merge commit' run_publisher
assert_log 'missing merge commit' ''

setup_case annotated_baseline
git -C "$case_repo" tag -d 0.2.0 >/dev/null
git -C "$case_repo" push -q origin :refs/tags/0.2.0
git -C "$case_repo" tag -a 0.2.0 "$baseline_sha" -m 0.2.0
git -C "$case_repo" push -q origin refs/tags/0.2.0
assert_failure 'annotated stable baseline' run_publisher
assert_log 'annotated stable baseline' ''

[ "$failures" -eq 0 ] || exit 1
printf '%s\n' 'publisher contract: OK'
```

Implement and assert these cases independently:

```text
no_label             success; mutations.tsv empty
create               success; ref 0.2.1 + Release 0.2.1
resume               precreate target tag; success; no ref mutation + Release 0.2.1
noop                 precreate target tag and published entry; success; no mutations
wait_refresh         target is minor; sleep mutation, then ref + Release 0.3.0
conflict_422         success; one ref attempt, refreshed resume, Release 0.2.1
non_422              failure; ref attempt only; no Release mutation
release_failure_once first run failure after ref; second run success by resume; one ref total and two Release attempts
bad_merge_sha        failure before mutation
annotated_baseline   replace 0.2.0 with an annotated tag; failure before mutation
```

The test ends with `publisher contract: OK` only when its failure counter is
zero. It must verify exact tab-separated mutation rows, not substring counts.

- [ ] **Step 3: Run publisher tests to verify RED**

```sh
sh scripts/test-publish-release.sh
```

Expected: nonzero because `scripts/publish-release.sh` is absent.

- [ ] **Step 4: Implement normalized state collection**

Assemble `scripts/publish-release.sh` in one exact order: shebang and `set -eu`;
argument, environment, tool, and checkout validation; function definitions;
temporary-file allocation; then the first context invocation. Begin with:

```sh
#!/bin/sh

set -eu
[ "$#" -eq 2 ] || { printf '%s\n' 'usage: publish-release.sh REPOSITORY TARGET_SHA' >&2; exit 2; }
repository=$1
target_sha=$2
case "$repository" in */*) ;; *) printf '%s\n' 'release publication: invalid repository' >&2; exit 1 ;; esac
case "$target_sha" in *[!0-9a-f]*|'') printf '%s\n' 'release publication: invalid target SHA' >&2; exit 1 ;; esac
[ "${#target_sha}" -eq 40 ] || { printf '%s\n' 'release publication: target SHA must be full length' >&2; exit 1; }
[ -n "${GH_TOKEN:-}" ] || { printf '%s\n' 'release publication: GH_TOKEN is required' >&2; exit 1; }
GH_BIN=${GH_BIN:-gh}
JQ_BIN=${JQ_BIN:-jq}
SLEEP_BIN=${SLEEP_BIN:-sleep}
release_max_attempts=${RELEASE_MAX_ATTEMPTS:-60}
release_wait_seconds=${RELEASE_WAIT_SECONDS:-15}
case "$release_max_attempts" in *[!0-9]*|'0'|'') printf '%s\n' 'release publication: invalid max attempts' >&2; exit 1 ;; esac
case "$release_wait_seconds" in *[!0-9]*|'') printf '%s\n' 'release publication: invalid wait seconds' >&2; exit 1 ;; esac
for required_tool in git "$GH_BIN" "$JQ_BIN" "$SLEEP_BIN"; do
    command -v "$required_tool" >/dev/null 2>&1 || {
        printf '%s\n' "release publication: missing tool: $required_tool" >&2
        exit 1
    }
done
[ "$(git rev-parse HEAD)" = "$target_sha" ] || {
    printf '%s\n' 'release publication: checkout does not match target SHA' >&2
    exit 1
}
script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
```

Then define these exact functions before any call to them:

```sh
context_for_target() { GH_BIN="$GH_BIN" JQ_BIN="$JQ_BIN" sh "$script_dir/release-context-for-sha.sh" "$repository" "$target_sha"; }
refresh_tags() {
    git fetch --force --tags origin
    git fetch --no-tags origin main
    main_sha=$(git rev-parse origin/main)
    validate_commit_sha "$main_sha" origin/main
    if is_ancestor_checked "$target_sha" "$main_sha"; then
        :
    else
        ancestry_status=$?
        [ "$ancestry_status" -eq 1 ] && \
            printf '%s\n' 'release publication: target is no longer on main' >&2
        return 1
    fi
}
read_plan_value() { awk -F= -v key="$1" '$1 == key { print substr($0, length(key) + 2) }' "$plan_file"; }
read_context_value() { printf '%s\n' "$context" | awk -F= -v key="$1" '$1 == key { print substr($0, length(key) + 2) }'; }
validate_commit_sha() {
    case "$1" in *[!0-9a-f]*|'') printf '%s\n' "release publication: invalid $2" >&2; return 1 ;; esac
    [ "${#1}" -eq 40 ] || { printf '%s\n' "release publication: short $2" >&2; return 1; }
    git cat-file -e "$1^{commit}" >/dev/null 2>&1 || {
        printf '%s\n' "release publication: missing commit for $2: $1" >&2
        return 1
    }
}
is_ancestor_checked() {
    if git merge-base --is-ancestor "$1" "$2" >/dev/null 2>&1; then
        return 0
    else
        ancestry_status=$?
    fi
    [ "$ancestry_status" -eq 1 ] && return 1
    printf '%s\n' "release publication: ancestry check failed: $1 -> $2" >&2
    return 2
}
```

After all function definitions, allocate temporary files and invoke the context
adapter:

```sh
release_tmp_root=${RUNNER_TEMP:-/tmp}
state_file=$(mktemp "$release_tmp_root/release-state.XXXXXX")
plan_file=$(mktemp "$release_tmp_root/release-plan.XXXXXX")
tag_file=$(mktemp "$release_tmp_root/release-tags.XXXXXX")
all_tags_file=$(mktemp "$release_tmp_root/release-all-tags.XXXXXX")
releases_file=$(mktemp "$release_tmp_root/releases.XXXXXX")
pulls_file=$(mktemp "$release_tmp_root/pulls.XXXXXX")
tag_release_file=$(mktemp "$release_tmp_root/release-tag-state.XXXXXX")
pr_state_file=$(mktemp "$release_tmp_root/release-pr-state.XXXXXX")
release_versions_file=$(mktemp "$release_tmp_root/release-versions.XXXXXX")
pull_rows_file=$(mktemp "$release_tmp_root/release-pulls.XXXXXX")
ancestor_versions_file=$(mktemp "$release_tmp_root/release-ancestors.XXXXXX")
tag_create_response=$(mktemp "$release_tmp_root/release-tag-create.XXXXXX")
tag_create_error=$(mktemp "$release_tmp_root/release-tag-error.XXXXXX")

context=$(context_for_target)
context_sha=$(read_context_value merge_sha)
bump=$(read_context_value bump)
if [ -z "$context_sha" ] && [ -z "$bump" ]; then
    printf '%s\n' 'release publication: no associated release pull request'
    exit 0
fi
[ "$context_sha" = "$target_sha" ] || {
    printf '%s\n' 'release publication: merge SHA does not match verified CI SHA' >&2
    exit 1
}
[ -n "$bump" ] || {
    printf '%s\n' 'release publication: merged pull request has no release label'
    exit 0
}
```

Implement `write_tag_release_state` so every polling iteration refreshes only
mutable refs and GitHub Releases:

```sh
write_tag_release_state() {
    : >"$tag_release_file"
    : >"$tag_file"

    git tag --list >"$all_tags_file"
    while IFS= read -r version; do
        if printf '%s\n' "$version" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'; then
            tag_type=$(git cat-file -t "refs/tags/$version")
            [ "$tag_type" = commit ] || {
                printf '%s\n' "release publication: stable tag is not lightweight: $version" >&2
                return 1
            }
            tag_sha=$(git rev-list -n 1 "$version")
            if is_ancestor_checked "$tag_sha" "$main_sha"; then
                :
            else
                ancestry_status=$?
                [ "$ancestry_status" -eq 1 ] && \
                    printf '%s\n' "release publication: stable tag is not on main: $version" >&2
                return 1
            fi
            printf 'tag\t%s\t%s\n' "$version" "$tag_sha"
        fi
    done <"$all_tags_file" >"$tag_file"
    cat "$tag_file" >>"$tag_release_file"

    "$GH_BIN" api --paginate --slurp \
        "repos/$repository/releases?per_page=100" >"$releases_file"
    while IFS="$(printf '\t')" read -r record version tag_sha; do
        release_state=$("$JQ_BIN" -r --arg version "$version" '
          [add[] | select(.tag_name == $version)] |
          if length == 0 then "missing"
          elif length > 1 then "invalid"
          elif .[0].draft then "draft"
          elif .[0].prerelease then "prerelease"
          else "published"
          end
        ' "$releases_file")
        [ "$release_state" != invalid ] || {
            printf '%s\n' "release publication: duplicate Releases for $version" >&2
            return 1
        }
        printf 'release\t%s\t%s\n' "$version" "$release_state" >>"$tag_release_file"
    done <"$tag_file"

    "$JQ_BIN" -r 'add[] | select(.tag_name | test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) | .tag_name' \
        "$releases_file" >"$release_versions_file"
    LC_ALL=C sort -u "$release_versions_file" -o "$release_versions_file"
    while IFS= read -r release_version; do
        awk -F '\t' -v version="$release_version" \
            '$1 == "tag" && $2 == version { found = 1 } END { exit !found }' \
            "$tag_file" || {
                printf '%s\n' "release publication: Release without tag: $release_version" >&2
                return 1
            }
    done <"$release_versions_file"

    LC_ALL=C sort "$tag_release_file" -o "$tag_release_file"
}
```

After the first `refresh_tags` and `write_tag_release_state`, select the initial
context baseline from published stable tags whose SHAs are strict ancestors of
`TARGET_SHA`:

```sh
select_initial_baseline() {
    : >"$ancestor_versions_file"
    while IFS="$(printf '\t')" read -r record version tag_sha; do
        [ "$record" = tag ] || continue
        [ "$tag_sha" != "$target_sha" ] || continue
        if is_ancestor_checked "$tag_sha" "$target_sha"; then
            :
        else
            ancestry_status=$?
            [ "$ancestry_status" -eq 1 ] && continue
            return "$ancestry_status"
        fi
        release_state=$(awk -F '\t' -v version="$version" \
            '$1 == "release" && $2 == version { print $3 }' "$tag_release_file")
        [ "$release_state" = published ] || continue
        printf '%s\n' "$version" >>"$ancestor_versions_file"
    done <"$tag_file"

    initial_baseline_version=$(sh "$script_dir/latest-stable-version.sh" \
        <"$ancestor_versions_file")
    initial_baseline_sha=$(awk -F '\t' -v version="$initial_baseline_version" \
        '$1 == "tag" && $2 == version { count += 1; sha = $3 }
         END { if (count != 1) exit 1; print sha }' "$tag_file")
    is_ancestor_checked "$initial_baseline_sha" "$target_sha"
    [ "$initial_baseline_sha" != "$target_sha" ]
}
```

This gives the published predecessor for a new target, a partial retry, and a
completed old rerun without being confused by newer descendant releases.

Then fetch merged pull request metadata once and cache only immutable merge-time
contexts in `(initial_baseline_sha, TARGET_SHA]`:

```sh
collect_pr_state_once() {
    baseline_sha=$1
    : >"$pr_state_file"
    "$GH_BIN" api --paginate --slurp \
        "repos/$repository/pulls?state=closed&base=main&per_page=100" >"$pulls_file"

    "$JQ_BIN" -r 'add[] | select(.merged_at != null) | [.number, .merge_commit_sha] | @tsv' \
        "$pulls_file" >"$pull_rows_file"
    while IFS="$(printf '\t')" read -r pr_number merge_sha; do
        validate_commit_sha "$merge_sha" "merge SHA for PR #$pr_number" || return 1
        if is_ancestor_checked "$merge_sha" "$target_sha"; then
            :
        else
            ancestry_status=$?
            [ "$ancestry_status" -eq 1 ] && continue
            return "$ancestry_status"
        fi
        [ "$merge_sha" = "$baseline_sha" ] && continue
        if is_ancestor_checked "$baseline_sha" "$merge_sha"; then
            :
        else
            ancestry_status=$?
            [ "$ancestry_status" -eq 1 ] && continue
            return "$ancestry_status"
        fi

        pr_context=$(GH_BIN="$GH_BIN" JQ_BIN="$JQ_BIN" \
            sh "$script_dir/release-context-for-sha.sh" "$repository" "$merge_sha")
        context_pr=$(printf '%s\n' "$pr_context" | awk -F= '$1 == "pr_number" { print $2 }')
        [ "$context_pr" = "$pr_number" ] || {
            printf '%s\n' "release publication: PR association mismatch for $merge_sha" >&2
            return 1
        }
        context_bump=$(printf '%s\n' "$pr_context" | awk -F= '$1 == "bump" { print $2 }')
        [ -n "$context_bump" ] || context_bump=none
        printf 'pr\t%s\t%s\t%s\n' "$pr_number" "$merge_sha" "$context_bump" >>"$pr_state_file"
    done <"$pull_rows_file"

    LC_ALL=C sort "$pr_state_file" -o "$pr_state_file"
}

write_state_file() {
    write_tag_release_state
    : >"$state_file"
    cat "$tag_release_file" "$pr_state_file" >>"$state_file"
    LC_ALL=C sort "$state_file" -o "$state_file"
}
```

The closed-PR list may be paginated once to find the bounded ancestry range,
but timeline reconstruction runs only for PRs after the initial published
baseline through the immutable target. Cache those rows for the entire poll.
If the baseline advances while waiting, the cached range is a safe superset and
the planner ignores rows at or before its rolling predecessor. Polling refreshes
only tags and Releases. Recheck `TARGET_SHA` against fresh `origin/main`
immediately before mutation so unexpected branch-ancestry drift fails closed.

- [ ] **Step 5: Implement bounded polling and the stale-state guard**

Use this control flow:

```sh
refresh_tags
write_tag_release_state
select_initial_baseline
collect_pr_state_once "$initial_baseline_sha"

attempt=1
while [ "$attempt" -le "$release_max_attempts" ]; do
    refresh_tags
    write_state_file
    sh "$script_dir/plan-release.sh" "$target_sha" "$bump" "$state_file" >"$plan_file"
    action=$(read_plan_value action)
    [ "$action" = wait ] || break
    blocker=$(read_plan_value blocker_pr)
    printf '%s\n' "release publication: waiting for PR #$blocker"
    "$SLEEP_BIN" "$release_wait_seconds"
    attempt=$((attempt + 1))
done
[ "$action" != wait ] || { printf '%s\n' 'release publication: predecessor wait timed out' >&2; exit 1; }

planned_action=$action
planned_previous=$(read_plan_value previous)
planned_version=$(read_plan_value version)
case "$planned_action" in
    noop)
        [ "$(git rev-list -n 1 "$planned_version")" = "$target_sha" ] || {
            printf '%s\n' 'release publication: noop tag moved' >&2
            exit 1
        }
        [ "$(awk -F '\t' -v version="$planned_version" \
            '$1 == "release" && $2 == version { print $3 }' "$state_file")" = published ] || {
            printf '%s\n' 'release publication: noop Release is not published' >&2
            exit 1
        }
        exit 0
        ;;
    create|resume) ;;
    *) printf '%s\n' "release publication: unexpected action: $planned_action" >&2; exit 1 ;;
esac

refresh_tags
write_state_file
sh "$script_dir/plan-release.sh" "$target_sha" "$bump" "$state_file" >"$plan_file"
action=$(read_plan_value action)
previous=$(read_plan_value previous)
version=$(read_plan_value version)
[ "$action" = "$planned_action" ] && \
    [ "$previous" = "$planned_previous" ] && \
    [ "$version" = "$planned_version" ] || {
        printf '%s\n' 'release publication: release plan changed before mutation' >&2
        exit 1
    }
```

For `create` or `resume`, the code calls `refresh_tags`, `write_state_file`, and
the planner once more immediately before mutation and compares all three
transition fields. A later workflow retry re-enters from fresh state after any
drift failure. `refresh_tags`
also refreshes `origin/main` and performs its tri-state target ancestry check,
so call it immediately before mutation. This refresh is mandatory after every
wait. Cached PR contexts remain valid because the target
commit and its preceding Git ancestry are immutable; unexpected current-main
drift is caught by the final ancestry check.

- [ ] **Step 6: Implement exact tag and Release creation**

The preceding `noop` branch verifies the tag and published Release before
exiting. Only `create` creates the lightweight ref atomically; `resume` skips
the entire ref/422 block because its validated target tag already exists:

```sh
if [ "$action" = create ]; then
    if "$GH_BIN" api --method POST "repos/$repository/git/refs" \
        -f ref="refs/tags/$version" \
        -f sha="$target_sha" \
        >"$tag_create_response" 2>"$tag_create_error"; then
        :
    else
        if ! grep -Eq 'HTTP 422([^0-9]|$)' "$tag_create_error"; then
            cat "$tag_create_error" >&2
            exit 1
        fi

        existing_ref_sha=$("$GH_BIN" api \
            "repos/$repository/git/ref/tags/$version" \
            --jq 'select(.object.type == "commit") | .object.sha') || {
                cat "$tag_create_error" >&2
                exit 1
            }
        [ -n "$existing_ref_sha" ] || {
            cat "$tag_create_error" >&2
            printf '%s\n' 'release publication: conflicting tag is not lightweight' >&2
            exit 1
        }

        refresh_tags
        write_state_file
        sh "$script_dir/plan-release.sh" "$target_sha" "$bump" "$state_file" >"$plan_file"
        conflict_action=$(read_plan_value action)
        conflict_version=$(read_plan_value version)
        [ "$conflict_version" = "$version" ] || {
            printf '%s\n' 'release publication: tag conflict changed candidate version' >&2
            exit 1
        }
        case "$conflict_action" in
            resume) : ;;
            noop) exit 0 ;;
            *) printf '%s\n' 'release publication: tag conflict is inconsistent' >&2; exit 1 ;;
        esac
    fi
fi
```

Only an HTTP 422 followed by a successful read of the exact lightweight ref may
enter conflict recovery. Authentication, network, validation, and other API
failures surface immediately. The refreshed planner proves whether the same SHA
became `resume`/`noop`; a different SHA is a hard failure. For `create` and
`resume`, generate notes and publish without editing an existing Release:

```sh
notes_json=$("$GH_BIN" api --method POST "repos/$repository/releases/generate-notes" \
    -f tag_name="$version" \
    -f target_commitish="$target_sha" \
    -f previous_tag_name="$previous")
notes_body=$(printf '%s\n' "$notes_json" | "$JQ_BIN" -r '.body')

"$GH_BIN" api --method POST "repos/$repository/releases" \
    -f tag_name="$version" \
    -f target_commitish="$target_sha" \
    -f name="$version" \
    -f body="$notes_body" \
    -F draft=false \
    -F prerelease=false
```

Never call a tag update, forced push, Release update, or Release deletion
endpoint.

- [ ] **Step 7: Add generated-note categories**

Create `.github/release.yml`:

```yaml
changelog:
  categories:
    - title: Breaking Changes
      labels:
        - semver:major
    - title: New Features
      labels:
        - semver:minor
    - title: Fixes
      labels:
        - semver:patch
    - title: Other Changes
      labels:
        - "*"
```

- [ ] **Step 8: Create the privileged workflow boundary**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  workflow_run:
    workflows: [CI]
    types: [completed]
    branches: [main]

permissions:
  contents: read

jobs:
  release:
    if: >-
      github.event.workflow_run.conclusion == 'success' &&
      github.event.workflow_run.event == 'push' &&
      github.event.workflow_run.head_branch == 'main' &&
      github.event.workflow_run.head_repository.full_name == github.repository
    runs-on: ubuntu-24.04
    concurrency:
      group: release-${{ github.event.workflow_run.head_sha }}
      cancel-in-progress: false
    permissions:
      contents: write
      issues: read
      pull-requests: read
    env:
      GH_TOKEN: ${{ github.token }}
      TARGET_SHA: ${{ github.event.workflow_run.head_sha }}
    steps:
      - name: Checkout verified main commit
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
        with:
          ref: ${{ github.event.workflow_run.head_sha }}
          fetch-depth: 0
          persist-credentials: false
      - name: Record publication tools
        shell: bash
        run: |
          git --version
          gh --version
          jq --version
      - name: Verify target is on main
        shell: bash
        run: |
          git fetch --no-tags origin main
          git merge-base --is-ancestor "$TARGET_SHA" origin/main
      - name: Publish authorized release
        shell: bash
        run: sh scripts/publish-release.sh "$GITHUB_REPOSITORY" "$TARGET_SHA"
```

In `.github/workflows/ci.yml`, replace the single-line Release contract step
with:

```yaml
      - name: Validate release contracts
        run: |
          sh scripts/test-release-contract.sh
          sh scripts/test-publish-release.sh
```

- [ ] **Step 9: Run behavioral, workflow, and security verification**

```sh
sh -n scripts/publish-release.sh scripts/test-publish-release.sh \
  scripts/test-fixtures/fake-release-gh.sh \
  scripts/test-fixtures/fake-release-sleep.sh
sh scripts/test-release-contract.sh
sh scripts/test-publish-release.sh
actionlint .github/workflows/ci.yml .github/workflows/release.yml
grep -Fq "workflow_run:" .github/workflows/release.yml
grep -Fq "github.event.workflow_run.event == 'push'" .github/workflows/release.yml
! grep -Fq 'contents: write' .github/workflows/ci.yml
! grep -Eq 'artifact|cache' .github/workflows/release.yml
```

Expected: all checks exit zero and no untrusted artifact/cache path exists.

- [ ] **Step 10: Commit trusted publication**

```sh
git add scripts/publish-release.sh scripts/test-publish-release.sh \
  scripts/test-fixtures/fake-release-gh.sh \
  scripts/test-fixtures/fake-release-sleep.sh \
  scripts/test-release-contract.sh .github/workflows/ci.yml \
  .github/workflows/release.yml .github/release.yml
git commit -m "ci: automate verified semver releases"
```

---

### Task 6: Make the release policy discoverable and executable

**Files:**
- Create: `docs/RELEASING.md`
- Modify: `scripts/validate-documentation.sh`
- Modify: `CONTRIBUTING.md`
- Modify: `AGENTS.md`
- Modify: `docs/README.md`

**Interfaces:**
- `docs/RELEASING.md` owns label authorization, versioning, publication, ordering, retry, and permission policy.
- `scripts/validate-documentation.sh` rejects trust-boundary drift and obsolete workflows without treating historical planning records as active policy.

- [ ] **Step 1: Add failing documentation assertions first**

Add this helper beside `require_file`:

```sh
reject_file() {
    if [ -e "$1" ]; then
        fail "obsolete file must not exist: $1"
    fi
}
```

Add exact file requirements:

```sh
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
```

Require these stable strings and reject the old active merge gate:

```sh
require_text CONTRIBUTING.md '[`Release Guide`](docs/RELEASING.md)'
require_text CONTRIBUTING.md '`semver:major`'
require_text CONTRIBUTING.md '`semver:minor`'
require_text CONTRIBUTING.md '`semver:patch`'
require_text CONTRIBUTING.md '`release-label`'
require_text CONTRIBUTING.md '`build-and-test`'
reject_text CONTRIBUTING.md 'GitHub Build, Test, and Gitlint checks are successful'

require_text docs/README.md '[Release Guide](RELEASING.md)'
require_text AGENTS.md '`docs/RELEASING.md` owns release authorization'

require_text .github/workflows/ci.yml 'contents: read'
reject_text .github/workflows/ci.yml 'contents: write'
require_text .github/workflows/release.yml 'workflow_run:'
require_text .github/workflows/release.yml "github.event.workflow_run.event == 'push'"
require_text .github/workflows/release.yml 'contents: write'
require_text .github/workflows/release.yml 'scripts/publish-release.sh'
```

Run `sh scripts/validate-documentation.sh` and require RED because
`docs/RELEASING.md` and routing text are absent.

- [ ] **Step 2: Create the canonical Release Guide**

Create `docs/RELEASING.md` with this complete contract:

```md
# Releasing

This guide is the canonical release contract for maintainers, contributors,
and AI agents. It covers stable GitHub Releases produced from pull requests
merged into `main`.

## Release Authorization

Exactly three labels can authorize a stable release:

| Label | Result from `0.2.0` |
| --- | --- |
| `semver:major` | `1.0.0` |
| `semver:minor` | `0.3.0` |
| `semver:patch` | `0.2.1` |

No SemVer label is the normal no-release mode. Exactly one label authorizes
automatic publication after successful push CI. More than one supported label,
a duplicate label record, or any unsupported `semver:*` label fails closed.
Commit text never selects a version.

The labels active at the pull request's `merged` timeline event are
authoritative. Later edits to the closed pull request cannot create, suppress,
or change its release.

## Version Calculation

Tags are unprefixed, lightweight, stable `X.Y.Z` refs. Prerelease and build
metadata are outside this policy. Version components are compared numerically:

- `semver:patch`: `0.2.0 -> 0.2.1`;
- `semver:minor`: `0.2.0 -> 0.3.0`;
- `semver:major`: `0.2.0 -> 1.0.0`.

The predecessor must be a published stable Release on the protected `main`
ancestry. Tags are never overwritten or force-pushed.

## CI and Publication Boundary

`.github/workflows/ci.yml` is read-only. Its required checks are
`release-label` and `build-and-test`. Build and test share one SwiftPM build:
`swift build --build-tests` compiles sources and tests, then
`swift test --skip-build` runs the existing test bundle.

`.github/workflows/release.yml` receives write permission only after successful
push CI for the exact `main` SHA. It does not execute for pull request events,
restore pull request caches, or consume pull request artifacts. Publication
revalidates the associated pull request, merge SHA, merge-time label, Git
ancestry, tag, and Release state before every mutation.

## Generated Release Notes

GitHub generates notes from the preceding stable tag. Major, minor, and patch
pull requests appear under Breaking Changes, New Features, and Fixes.
Unlabeled pull requests since the predecessor appear under Other Changes.
Historical Release descriptions are not regenerated.

## Ordering and Retries

Every qualifying merge has its own idempotent release run. A later merge waits
up to 15 minutes while an earlier qualifying ancestor is unpublished. Ordering
comes from Git ancestry, not workflow queue order, pull request number, API
order, or timestamps. Tags and Releases are refreshed after every wait and
again immediately before mutation.

A completed old rerun is a no-op even when newer descendant Releases exist. A
partial target tag can be resumed only when it is the highest stable tag and is
the exact approved bump from a published predecessor.

## Failure Recovery

If tag creation succeeds and Release creation fails, rerun the failed Release
workflow. The rerun verifies the existing lightweight tag at the exact CI SHA
and creates only the missing Release. If both already exist consistently, the
rerun performs no write. A wrong tag owner, wrong bump, missing predecessor,
draft/prerelease state, divergent tag, ambiguous pull request, or bounded-wait
timeout requires investigation; automation never rewrites history.

## Permissions and Human Authority

The repository `GITHUB_TOKEN` creates tags and Releases; no personal token is
required. CI is read-only, and only the trusted Release job receives
`contents: write`. An AI agent may add or remove a release label, rerun a
release, or otherwise change release state only after explicit human
authorization. Merge still requires the repository's independent review rules.

## Verification Boundary

Offline contract tests cover labels, merge timelines, SemVer, ancestry,
ordering, retries, API failures, and tag/Release mutations with disposable Git
repositories and fake GitHub commands. Pull request CI covers documentation,
compilation, and tests without write permission. The first future merge carrying
exactly one `semver:*` label is the first production end-to-end publication
test; report that path as unverified until it occurs.
```

- [ ] **Step 3: Update contributor policy**

In `CONTRIBUTING.md`:

1. add `docs/RELEASING.md` to Sources of Truth as the owner of release policy;
2. keep `.gitlint` and Conventional Commits in `## Commits and Pull Requests`;
3. add a link with exact label meanings and state that selecting one label
   authorizes automatic publication after merge;
4. replace the final `GitHub Build, Test, and Gitlint` bullet with:

```md
- GitHub `release-label` and `build-and-test` checks are successful;
```

5. state that absence of a SemVer label is the normal no-release mode.

- [ ] **Step 4: Update agent routing and documentation map**

Add this ownership sentence to `AGENTS.md` without changing `## Git Scope`:

```md
`docs/RELEASING.md` owns release authorization, SemVer calculation, publication, and recovery policy.
```

Add this Task Routing bullet:

```md
- For release labels, version calculation, tag or GitHub Release work, read `docs/RELEASING.md` and preserve its human-authorization boundary.
```

Add this row to `docs/README.md`:

```md
| Select a version bump or recover a release | [Release Guide](RELEASING.md) |
```

Add the Release Guide to Source Precedence as the owner of release policy.

- [ ] **Step 5: Verify documentation GREEN**

```sh
sh -n scripts/validate-documentation.sh
sh scripts/validate-documentation.sh
```

Expected: `documentation contract: OK`.

- [ ] **Step 6: Commit the release documentation contract**

```sh
git add docs/RELEASING.md CONTRIBUTING.md AGENTS.md docs/README.md scripts/validate-documentation.sh
git commit -m "docs: document semver release workflow"
```

---

### Task 7: Run the complete local verification gate

**Files:**
- Inspect: all files created, modified, and deleted by Tasks 1-6.

**Interfaces:**
- Consumes: the completed local implementation.
- Produces: evidence suitable for the Draft pull request and a clean, scoped branch.

- [ ] **Step 1: Run all shell and policy checks**

```sh
sh -n \
  scripts/validate-release-labels.sh \
  scripts/release-labels-at-merge.sh \
  scripts/latest-stable-version.sh \
  scripts/next-semver.sh \
  scripts/plan-release.sh \
  scripts/release-context-for-sha.sh \
  scripts/publish-release.sh \
  scripts/test-release-contract.sh \
  scripts/test-publish-release.sh \
  scripts/test-fixtures/fake-gh.sh \
  scripts/test-fixtures/fake-release-gh.sh \
  scripts/test-fixtures/fake-release-sleep.sh \
  scripts/validate-documentation.sh
sh scripts/test-release-contract.sh
sh scripts/test-publish-release.sh
sh scripts/validate-documentation.sh
actionlint .github/workflows/ci.yml .github/workflows/release.yml
git diff --check origin/main...HEAD
```

Expected: both contract scripts print `OK`; all other commands exit zero.

- [ ] **Step 2: Verify one-build test reuse locally**

```sh
swift build --build-tests
swift test --skip-build
```

Expected: build exits zero and all 21 current tests pass without a compile step
in the second command.

- [ ] **Step 3: Run the repository baseline for compatibility**

```sh
swift test
swift build
```

Expected: all 21 tests pass and the package builds with unchanged API and
manifest.

- [ ] **Step 4: Audit security and scope**

```sh
rg -n 'contents: write|pull_request_target|artifact|cache' .github/workflows scripts
rg -n 'GitHub Build, Test, and Gitlint|release:none|macos-latest' CONTRIBUTING.md AGENTS.md docs scripts .github
git status --short
git diff origin/main...HEAD --stat
git diff origin/main...HEAD -- . ':!docs/superpowers/specs/*' ':!docs/superpowers/plans/*'
```

Confirm `contents: write` appears only in `.github/workflows/release.yml`,
`pull_request_target` is absent, release workflow artifacts/caches are absent,
`.gitlint` remains tracked, Swift/package files are unchanged, and the only
legacy Gitlint wording is in historical planning records.

- [ ] **Step 5: Inspect commit boundaries**

```sh
git log --oneline origin/docs/contribution-workflow..HEAD
git status --short --branch
```

Expected: one focused commit for each completed task and no uncommitted files.

---

### Task 8: Publish the branch and validate new GitHub checks

**Files:**
- External: branch `docs/contribution-workflow`
- External: Draft pull request #3

**Interfaces:**
- Consumes: Task 7 evidence and explicit human authorization to push.
- Produces: live `release-label` and `build-and-test` check contexts for the new commit.

- [ ] **Step 1: Reconfirm branch and remote before push**

```sh
git status --short --branch
git remote -v
git log --oneline origin/docs/contribution-workflow..HEAD
```

Require the expected branch, clean worktree, and only reviewed local commits.

- [ ] **Step 2: Push without changing PR state**

```sh
git push origin docs/contribution-workflow
```

Do not mark the PR ready and do not apply a SemVer label.

- [ ] **Step 3: Wait for exact required checks**

```sh
gh pr checks 3 --repo inekipelov/swift-backport-pattern --watch
```

Require successful `release-label` and `build-and-test`. The privileged Release
workflow must not run for this pull request event.

- [ ] **Step 4: Perform a read-only API dry run**

Use a known merged PR SHA only for association/timeline normalization:

```sh
gh api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  repos/inekipelov/swift-backport-pattern/commits/e58de6cf1279561775c24aeea49e12664499708e/pulls
sh scripts/release-context-for-sha.sh \
  inekipelov/swift-backport-pattern \
  e58de6cf1279561775c24aeea49e12664499708e
```

Require the script to report PR #2, the exact merge SHA, and an empty bump. Do
not create a tag or Release. Report that end-to-end publication remains
unverified until a future qualifying merge.

---

### Task 9: Apply the reviewed GitHub label and ruleset configuration

**Files:**
- External: repository labels
- External: ruleset `Defaults`
- External: Draft pull request #3 title and body

**Interfaces:**
- Consumes: successful live checks from Task 8.
- Produces: the exact three-label allowlist, two required checks, and an accurate Draft PR description.

Run Steps 1-6 in one foreground shell session so validated variables and the
temporary audit directory cannot disappear between commands. Enable `set -eu`
before assigning any mutation target; stop the session on the first error.

- [ ] **Step 1: Audit labels and every assignment before deletion**

Create a temporary audit directory and record live state:

```sh
set -eu
release_audit_dir=$(mktemp -d)
gh api --paginate --slurp \
  'repos/inekipelov/swift-backport-pattern/labels?per_page=100' \
  >"$release_audit_dir/labels-before.pages.json"
jq 'add' "$release_audit_dir/labels-before.pages.json" \
  >"$release_audit_dir/labels-before.json"
gh api --paginate --slurp \
  'repos/inekipelov/swift-backport-pattern/issues?state=all&per_page=100' \
  >"$release_audit_dir/issues-before.pages.json"
jq -r 'add[] | .number as $number | .labels[]?.name | [$number, .] | @tsv' \
  "$release_audit_dir/issues-before.pages.json" \
  >"$release_audit_dir/assignments-before.tsv"
jq -r '.[].name | select(. != "semver:major" and . != "semver:minor" and . != "semver:patch")' \
  "$release_audit_dir/labels-before.json" | LC_ALL=C sort \
  >"$release_audit_dir/delete-labels-before.txt"
```

Print the exact delete and assignment files. If
`assignments-before.tsv` contains any label listed in
`delete-labels-before.txt`, stop and report the issue/PR number instead of
deleting:

```sh
awk -F '\t' 'NR == FNR { targets[$0] = 1; next } ($2 in targets)' \
  "$release_audit_dir/delete-labels-before.txt" \
  "$release_audit_dir/assignments-before.tsv" \
  >"$release_audit_dir/blocking-assignments-before.tsv"
test ! -s "$release_audit_dir/blocking-assignments-before.tsv"
```

- [ ] **Step 2: Create or update the three allowed labels**

```sh
gh label create 'semver:major' --repo inekipelov/swift-backport-pattern \
  --color d73a4a --description 'Publish the next stable major release after merge' --force
gh label create 'semver:minor' --repo inekipelov/swift-backport-pattern \
  --color 1d76db --description 'Publish the next stable minor release after merge' --force
gh label create 'semver:patch' --repo inekipelov/swift-backport-pattern \
  --color 0e8a16 --description 'Publish the next stable patch release after merge' --force
```

- [ ] **Step 3: Repeat the complete audit, reject drift, then delete inspected labels**

Immediately after the allowed-label updates, fetch every label and every open or
closed assignment again. Recompute the exact delete set, require it to equal the
reviewed pre-mutation set, and stop before deletion on any new assignment:

```sh
gh api --paginate --slurp \
  'repos/inekipelov/swift-backport-pattern/labels?per_page=100' \
  >"$release_audit_dir/labels-current.pages.json"
jq 'add' "$release_audit_dir/labels-current.pages.json" \
  >"$release_audit_dir/labels-current.json"
gh api --paginate --slurp \
  'repos/inekipelov/swift-backport-pattern/issues?state=all&per_page=100' \
  >"$release_audit_dir/issues-current.pages.json"
jq -r 'add[] | .number as $number | .labels[]?.name | [$number, .] | @tsv' \
  "$release_audit_dir/issues-current.pages.json" \
  >"$release_audit_dir/assignments-current.tsv"
jq -r '.[].name | select(. != "semver:major" and . != "semver:minor" and . != "semver:patch")' \
  "$release_audit_dir/labels-current.json" | LC_ALL=C sort \
  >"$release_audit_dir/delete-labels-current.txt"

cmp -s "$release_audit_dir/delete-labels-before.txt" \
  "$release_audit_dir/delete-labels-current.txt" || {
    printf '%s\n' 'label set changed during review; refusing to delete' >&2
    exit 1
  }
awk -F '\t' 'NR == FNR { targets[$0] = 1; next } ($2 in targets)' \
  "$release_audit_dir/delete-labels-current.txt" \
  "$release_audit_dir/assignments-current.tsv" \
  >"$release_audit_dir/blocking-assignments-current.tsv"
test ! -s "$release_audit_dir/blocking-assignments-current.tsv"

while IFS= read -r label; do
  [ -n "$label" ] || continue
  case "$label" in
    semver:major|semver:minor|semver:patch)
      printf '%s\n' "refusing to delete allowed label: $label" >&2
      exit 1
      ;;
  esac
  printf '%s\n' "deleting label: $label"

  gh api --paginate --slurp \
    'repos/inekipelov/swift-backport-pattern/labels?per_page=100' \
    >"$release_audit_dir/labels-recheck.pages.json"
  jq -e --arg label "$label" \
    '[add[] | .name] | index($label) != null' \
    "$release_audit_dir/labels-recheck.pages.json" >/dev/null
  gh api --paginate --slurp \
    'repos/inekipelov/swift-backport-pattern/issues?state=all&per_page=100' \
    >"$release_audit_dir/issues-recheck.pages.json"
  jq -e --arg label "$label" \
    '[add[] | .labels[]?.name] | index($label) == null' \
    "$release_audit_dir/issues-recheck.pages.json" >/dev/null
  gh label delete "$label" --repo inekipelov/swift-backport-pattern --yes
done <"$release_audit_dir/delete-labels-current.txt"
```

The per-target assignment read is intentionally adjacent to deletion; GitHub
does not expose an atomic label-assignment/delete transaction. A concurrent
change aborts when observable, and final drift leaves the task incomplete
rather than broadening deletion. After the loop, require the fully paginated
live set to equal an exact allowlist file:

```sh
printf '%s\n' semver:major semver:minor semver:patch | LC_ALL=C sort \
  >"$release_audit_dir/allowed-labels.txt"
gh api --paginate --slurp \
  'repos/inekipelov/swift-backport-pattern/labels?per_page=100' \
  >"$release_audit_dir/labels-after.pages.json"
jq -r 'add | sort_by(.name) | .[].name' \
  "$release_audit_dir/labels-after.pages.json" \
  >"$release_audit_dir/labels-after.names"
diff -u "$release_audit_dir/allowed-labels.txt" \
  "$release_audit_dir/labels-after.names"
```

- [ ] **Step 4: Re-read and validate the active ruleset**

Resolve exactly one active default-branch ruleset named `Defaults`, fetch it,
and require no existing `required_status_checks` rule unless it already equals
the desired two contexts:

```sh
ruleset_id=$(gh api --paginate --slurp \
  'repos/inekipelov/swift-backport-pattern/rulesets?per_page=100' \
  --jq 'add | [.[] | select(.name == "Defaults" and .enforcement == "active")] | if length == 1 then .[0].id else error("expected one Defaults ruleset") end')
case "$ruleset_id" in ''|*[!0-9]*) printf '%s\n' 'invalid ruleset id' >&2; exit 1 ;; esac
gh api "repos/inekipelov/swift-backport-pattern/rulesets/$ruleset_id" \
  >"$release_audit_dir/ruleset-before.json"

required_rule_count=$(jq '[.rules[] | select(.type == "required_status_checks")] | length' \
  "$release_audit_dir/ruleset-before.json")
case "$required_rule_count" in
  0) ruleset_update_needed=1 ;;
  1)
    jq -e '
      [.rules[] | select(.type == "required_status_checks")][0].parameters as $p |
      $p.strict_required_status_checks_policy == false and
      $p.do_not_enforce_on_create == false and
      ($p.required_status_checks | map(.context) | sort) == ["build-and-test", "release-label"]
    ' "$release_audit_dir/ruleset-before.json" >/dev/null
    ruleset_update_needed=0
    ;;
  *) printf '%s\n' 'unexpected required status check rules' >&2; exit 1 ;;
esac
```

Require the live target and every approved non-status rule before preparing an
update:

```sh
jq -e '
  .name == "Defaults" and
  .target == "branch" and
  .enforcement == "active" and
  .conditions.ref_name.include == ["~DEFAULT_BRANCH"] and
  .conditions.ref_name.exclude == [] and
  ([.rules[] | select(.type != "required_status_checks") | .type] | sort) ==
    ["deletion", "non_fast_forward", "pull_request"] and
  ([.rules[] | select(.type == "pull_request")][0].parameters as $p |
    $p.required_approving_review_count == 1 and
    $p.dismiss_stale_reviews_on_push == false and
    $p.require_code_owner_review == true and
    $p.require_last_push_approval == true and
    $p.required_review_thread_resolution == false and
    $p.required_reviewers == [] and
    ($p.allowed_merge_methods | sort) == ["merge", "rebase", "squash"])
' "$release_audit_dir/ruleset-before.json" >/dev/null
```

- [ ] **Step 5: Add only the two required status checks**

When `ruleset_update_needed=1`, build the PUT body by preserving all live fields
accepted by the update API and appending one rule:

```sh
jq '{
  name,
  target,
  enforcement,
  bypass_actors,
  conditions,
  rules: (.rules + [{
    type: "required_status_checks",
    parameters: {
      strict_required_status_checks_policy: false,
      do_not_enforce_on_create: false,
      required_status_checks: [
        {context: "release-label"},
        {context: "build-and-test"}
      ]
    }
  }])
}' "$release_audit_dir/ruleset-before.json" >"$release_audit_dir/ruleset-update.json"

if [ "$ruleset_update_needed" -eq 1 ]; then
  gh api "repos/inekipelov/swift-backport-pattern/rulesets/$ruleset_id" \
    >"$release_audit_dir/ruleset-current.json"
  jq -S . "$release_audit_dir/ruleset-before.json" >"$release_audit_dir/ruleset-before.canonical.json"
  jq -S . "$release_audit_dir/ruleset-current.json" >"$release_audit_dir/ruleset-current.canonical.json"
  cmp -s "$release_audit_dir/ruleset-before.canonical.json" \
    "$release_audit_dir/ruleset-current.canonical.json" || {
      printf '%s\n' 'ruleset changed during review; refusing to overwrite' >&2
      exit 1
    }
  gh api --method PUT \
    "repos/inekipelov/swift-backport-pattern/rulesets/$ruleset_id" \
    --input "$release_audit_dir/ruleset-update.json" \
    >"$release_audit_dir/ruleset-after.json"
else
  cp "$release_audit_dir/ruleset-before.json" "$release_audit_dir/ruleset-after.json"
fi
```

Project every mutation-owned field except `required_status_checks` from both
responses and require byte-identical canonical JSON. Then require exactly the
desired status rule after the PUT:

```sh
for ruleset_side in before after; do
  jq -S '{
    name,
    target,
    enforcement,
    bypass_actors,
    conditions,
    rules: ([.rules[] | select(.type != "required_status_checks")] | sort_by(.type))
  }' "$release_audit_dir/ruleset-$ruleset_side.json" \
    >"$release_audit_dir/ruleset-$ruleset_side.projection.json"
done
cmp -s "$release_audit_dir/ruleset-before.projection.json" \
  "$release_audit_dir/ruleset-after.projection.json" || {
    printf '%s\n' 'non-status ruleset fields changed unexpectedly' >&2
    exit 1
  }
jq -e '
  [.rules[] | select(.type == "required_status_checks")] as $rules |
  ($rules | length) == 1 and
  $rules[0].parameters.strict_required_status_checks_policy == false and
  $rules[0].parameters.do_not_enforce_on_create == false and
  ($rules[0].parameters.required_status_checks | map(.context) | sort) ==
    ["build-and-test", "release-label"]
' "$release_audit_dir/ruleset-after.json" >/dev/null
```

- [ ] **Step 6: Update the Draft PR without adding a release label**

Set the title to:

```text
ci: add contribution and semver release workflows
```

Update the body to report:

```md
## Summary

- add one shared contribution contract for developers, maintainers, and AI agents
- consolidate documentation validation, Swift build, and tests into read-only CI checks
- compile the package and test bundle once, then run tests with `--skip-build`
- validate merge-time `semver:*` labels and publish generated stable Releases from a separate trusted workflow
- document ordering, retry, permissions, and recovery behavior

## Risk and compatibility

Risk classification: **High-risk** because the change introduces automatic tag and GitHub Release publication and updates repository labels and required checks. Pull request code remains read-only; publication runs only after successful push CI on `main`. Swift API, dependencies, deployment targets, and `swift-tools-version` are unchanged.

## Verification

- release-contract shell syntax and fixture matrix — passed
- `sh scripts/test-publish-release.sh` — `publisher contract: OK`
- `sh scripts/validate-documentation.sh` — `documentation contract: OK`
- `actionlint .github/workflows/ci.yml .github/workflows/release.yml` — passed
- `swift build --build-tests` — passed
- `swift test --skip-build` — 21 tests passed
- `swift test` — 21 tests passed
- `swift build` — passed
- `git diff --check` — passed
- GitHub `release-label` and `build-and-test` checks — passed

The release workflow is intentionally not executed from this unlabeled Draft PR. The first future merge carrying exactly one `semver:*` label remains the end-to-end publication verification.

## AI assistance

Codex materially authored and self-reviewed the documentation, shell policy, and workflow changes. The human maintainer approved the design and execution. Independent human approval is still required before merge.
```

Use `apply_patch` to save that exact Markdown as
`$release_audit_dir/pr-body.md`, then run:

```sh
gh pr edit 3 --repo inekipelov/swift-backport-pattern \
  --title 'ci: add contribution and semver release workflows' \
  --body-file "$release_audit_dir/pr-body.md"
```

Keep PR #3 Draft and verify its labels remain empty.

- [ ] **Step 7: Final live-state verification**

```sh
gh pr view 3 --repo inekipelov/swift-backport-pattern \
  --json title,isDraft,labels,statusCheckRollup
gh api "repos/inekipelov/swift-backport-pattern/rulesets/$ruleset_id"
gh api --paginate --slurp \
  'repos/inekipelov/swift-backport-pattern/labels?per_page=100'
```

Completion requires: Draft remains true, PR labels are empty, both new checks
are successful, only three labels exist, and every non-status-check ruleset
field remains unchanged.

## Verification Boundary

Local fixtures and pull request CI prove label policy, version calculation,
retry planning, documentation, compilation, and test behavior. They do not
publish a real tag or GitHub Release. The first future qualifying merge is the
only safe end-to-end publication test; until then, report that path as
unverified rather than simulating a production release.
