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
assert_failure 'trailing TSV field' sh -c "printf '%s\\t%s\\t\\n%s\\n' labeled semver:patch merged | sh scripts/release-labels-at-merge.sh"
assert_failure 'trailing merged TSV field' sh -c "printf 'merged\\t\\n' | sh scripts/release-labels-at-merge.sh"

assert_equal 'patch transition' '0.2.1' "$(sh scripts/next-semver.sh 0.2.0 patch)"
assert_equal 'minor transition' '0.3.0' "$(sh scripts/next-semver.sh 0.2.0 minor)"
assert_equal 'major transition' '1.0.0' "$(sh scripts/next-semver.sh 0.2.0 major)"
assert_equal 'decimal carry' '0.10.0' "$(sh scripts/next-semver.sh 0.9.9 minor)"
assert_equal 'large decimal carry' '10.0.0' "$(sh scripts/next-semver.sh 9.9.9 major)"
assert_failure 'leading zero version' sh scripts/next-semver.sh 01.2.3 patch
assert_failure 'prerelease version' sh scripts/next-semver.sh 1.2.3-rc.1 patch
assert_failure 'missing version component' sh scripts/next-semver.sh 1.2 patch
assert_failure 'whitespace in version' sh scripts/next-semver.sh ' 1.2.3' patch
assert_failure 'embedded newline in version' sh scripts/next-semver.sh "$(printf '1.2.3\ninvalid')" patch
assert_failure 'unsupported bump' sh scripts/next-semver.sh 1.2.3 build

latest=$(printf '%s\n' 0.9.9 0.10.0 01.0.0 v9.0.0 1.0.0-rc.1 notes 2.0.0+build | sh scripts/latest-stable-version.sh)
assert_equal 'numeric stable maximum' '0.10.0' "$latest"
assert_failure 'missing stable baseline' sh -c "printf '%s\n' v1.0.0 1.0.0-rc.1 | sh scripts/latest-stable-version.sh"

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
assert_plan_error() {
    description=$1
    target=$2
    bump=$3
    expected=$4
    if (cd "$planner_root" && \
        sh "$project_root/scripts/plan-release.sh" "$target" "$bump" "$planner_state") \
        >/dev/null 2>"$planner_error"; then
        fail "$description: expected planner failure"
    else
        actual=$(cat "$planner_error")
        assert_equal "$description" "$expected" "$actual"
    fi
}

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
assert_plan_error 'candidate belongs to another SHA' "$patch_sha" patch \
    "release plan: candidate version already belongs to $minor_sha"

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)" \
    "$(tag_row 0.3.0 "$minor_sha")" "$(release_row 0.3.0 published)"
assert_plan_error 'descendant tag blocks create' "$patch_sha" patch \
    'release plan: cannot create release before descendant tag: 0.3.0'

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

write_planner_state \
    "$(printf 'pr\t10\t%s\tpatch\t' "$patch_sha")" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)"
assert_plan_failure 'trailing empty PR field' "$patch_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(printf 'tag\t0.2.0\t%s\t' "$baseline_sha")" "$(release_row 0.2.0 published)"
assert_plan_failure 'trailing empty tag field' "$patch_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(printf 'release\t0.2.0\tpublished\t')"
assert_plan_failure 'trailing empty Release field' "$patch_sha" patch

write_planner_state \
    "$(printf '\tpr\t10\t%s\tpatch' "$patch_sha")" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(release_row 0.2.0 published)"
assert_plan_failure 'leading empty PR field' "$patch_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(printf '\ttag\t0.2.0\t%s' "$baseline_sha")" "$(release_row 0.2.0 published)"
assert_plan_failure 'leading empty tag field' "$patch_sha" patch

write_planner_state \
    "$(pr_row 10 "$patch_sha" patch)" \
    "$(tag_row 0.2.0 "$baseline_sha")" "$(printf '\trelease\t0.2.0\tpublished')"
assert_plan_failure 'leading empty Release field' "$patch_sha" patch

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

if [ "$failures" -ne 0 ]; then
    exit 1
fi

printf '%s\n' 'release contract: OK'
