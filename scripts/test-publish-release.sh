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
