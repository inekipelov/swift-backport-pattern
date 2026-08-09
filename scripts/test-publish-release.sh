#!/bin/sh

set -eu
project_root=$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd)
test_path=$PATH
if command -v xcrun >/dev/null 2>&1; then
    test_git=$(xcrun -f git)
    test_path=${test_git%/*}:$PATH
fi
suite_root=$(mktemp -d)

cleanup_suite() {
    case "$suite_root" in */tmp.*) ;; *) return 1 ;; esac
    [ ! -L "$suite_root" ] || return 1
    rm -rf "$suite_root"
}
trap cleanup_suite 0

fail() { printf '%s\n' "publisher contract: $1" >&2; exit 1; }
assert_equal() {
    description=$1
    expected=$2
    actual=$3
    [ "$actual" = "$expected" ] || fail "$description: expected '$expected', got '$actual'"
}
assert_workflow_line() {
    description=$1
    expected=$2
    grep -Fqx "$expected" "$project_root/.github/workflows/release.yml" || \
        fail "$description: missing workflow contract"
}
assert_workflow_absent() {
    description=$1
    rejected=$2
    if grep -Fq "$rejected" "$project_root/.github/workflows/release.yml"; then
        fail "$description: rejected workflow contract is present"
    fi
}
assert_file_contents() {
    description=$1
    expected=$2
    file=$3
    expected_file="$case_root/expected.txt"
    if [ -n "$expected" ]; then
        printf '%s\n' "$expected" >"$expected_file"
    else
        : >"$expected_file"
    fi
    if ! cmp -s "$expected_file" "$file"; then
        printf '%s\n' "publisher contract: $description: expected bytes" >&2
        od -An -tx1 "$expected_file" >&2
        printf '%s\n' "publisher contract: $description: actual bytes" >&2
        od -An -tx1 "$file" >&2
        fail "$description: exact contents differ"
    fi
}
assert_attempts() { assert_file_contents "$1 attempts" "$2" "$case_state/mutations.tsv"; }
assert_requests() { assert_file_contents "$1 requests" "$2" "$case_state/requests.tsv"; }
assert_published() { assert_file_contents "$1 published state" "$2" "$case_state/published.txt"; }
assert_remote_tag() {
    description=$1
    version=$2
    expected=$3
    ls_remote_file="$case_root/ls-remote.txt"
    git -C "$case_repo" ls-remote --refs origin "refs/tags/$version" >"$ls_remote_file" || \
        fail "$description: ls-remote failed"
    actual=$(awk '{ print $1 }' "$ls_remote_file")
    [ "$actual" = "$expected" ] || fail "$description: unexpected remote tag state"
}
assert_temp_empty() {
    description=$1
    if [ -n "$(find "$case_tmp" -mindepth 1 -print -quit)" ]; then
        fail "$description: publisher temporary files remain"
    fi
}
assert_run() {
    description=$1
    expected_status=$2
    expected_stdout=$3
    expected_stderr=$4
    assert_equal "$description status" "$expected_status" "$case_status"
    assert_file_contents "$description stdout" "$expected_stdout" "$case_stdout"
    assert_file_contents "$description stderr" "$expected_stderr" "$case_stderr"
    assert_temp_empty "$description"
}

setup_case() {
    scenario=$1
    case_root=$(mktemp -d "$suite_root/case.XXXXXX")
    case_state="$case_root/state"
    case_repo="$case_root/work"
    case_remote="$case_root/origin.git"
    case_tmp="$case_root/tmp"
    case_stdout="$case_root/stdout.txt"
    case_stderr="$case_root/stderr.txt"
    mkdir "$case_state" "$case_tmp"
    : >"$case_state/mutations.tsv"
    : >"$case_state/requests.tsv"
    printf '%s\n' 0.2.0 >"$case_state/published.txt"
    git init -q --bare "$case_remote"
    git init -q -b main "$case_repo"
    git -C "$case_repo" config user.name 'Publisher Contract'
    git -C "$case_repo" config user.email 'publisher-contract@example.invalid'
    git -C "$case_repo" remote add origin "$case_remote"
    for commit_name in baseline earlier target current; do
        printf '%s\n' "$commit_name" >"$case_repo/state"
        git -C "$case_repo" add state
        git -C "$case_repo" commit -q -m "$commit_name"
        commit_sha=$(git -C "$case_repo" rev-parse HEAD)
        case "$commit_name" in
            baseline) baseline_sha=$commit_sha ;;
            earlier) earlier_sha=$commit_sha ;;
            target) target_sha=$commit_sha ;;
            current) current_sha=$commit_sha ;;
        esac
    done
    git -C "$case_repo" push -q -u origin main
    git -C "$case_repo" tag 0.2.0 "$baseline_sha"
    git -C "$case_repo" push -q origin refs/tags/0.2.0
}
teardown_case() {
    case "$case_root" in "$suite_root"/case.*) ;; *) fail 'unsafe case cleanup target' ;; esac
    [ ! -L "$case_root" ] || fail 'case cleanup target is a symlink'
    rm -rf "$case_root"
    [ ! -e "$case_root" ] || fail 'case cleanup failed'
}
precreate_target_tag() {
    version=${1:-0.2.1}
    git -C "$case_repo" tag "$version" "$target_sha"
    git -C "$case_repo" push -q origin "refs/tags/$version"
}
run_publisher() {
    (
        cd "$case_repo"
        env \
          PATH="$test_path" \
          GH_TOKEN=test-token \
          GH_BIN="$project_root/scripts/test-fixtures/fake-release-gh.sh" \
          JQ_BIN=jq \
          SLEEP_BIN="$project_root/scripts/test-fixtures/fake-release-sleep.sh" \
          RELEASE_MAX_ATTEMPTS=3 \
          RELEASE_WAIT_SECONDS=0 \
          RUNNER_TEMP="$case_tmp" \
          TMPDIR="$case_tmp" \
          FAKE_RELEASE_SCENARIO="$scenario" \
          FAKE_RELEASE_STATE_DIR="$case_state" \
          FAKE_GIT_REPO="$case_repo" \
          FAKE_BASELINE_SHA="$baseline_sha" \
          FAKE_EARLIER_SHA="$earlier_sha" \
          FAKE_TARGET_SHA="$target_sha" \
          FAKE_CURRENT_SHA="$current_sha" \
          sh "$project_root/scripts/publish-release.sh" owner/repository "$target_sha"
    )
}
capture_publisher() {
    : >"$case_stdout"
    : >"$case_stderr"
    if run_publisher >"$case_stdout" 2>"$case_stderr"; then
        case_status=0
    else
        case_status=$?
    fi
}
run_fake() {
    env \
      PATH="$test_path" \
      FAKE_RELEASE_SCENARIO="$scenario" \
      FAKE_RELEASE_STATE_DIR="$case_state" \
      FAKE_GIT_REPO="$case_repo" \
      FAKE_BASELINE_SHA="$baseline_sha" \
      FAKE_EARLIER_SHA="$earlier_sha" \
      FAKE_TARGET_SHA="$target_sha" \
      FAKE_CURRENT_SHA="$current_sha" \
      RUNNER_TEMP="$case_tmp" \
      TMPDIR="$case_tmp" \
      "$project_root/scripts/test-fixtures/fake-release-gh.sh" "$@"
}
assert_fake_failure() {
    description=$1
    shift
    if run_fake "$@" >/dev/null 2>&1; then
        fail "$description: fake accepted invalid request"
    fi
}

context_requests() {
    printf 'GET\trepos/owner/repository/commits/%s/pulls?per_page=100\n' "$1"
    printf 'GET\trepos/owner/repository/issues/%s/timeline?per_page=100\n' "$2"
}
target_context_requests() { context_requests "$target_sha" 20; }
earlier_context_requests() { context_requests "$earlier_sha" 10; }
release_state_request() { printf 'GET\trepos/owner/repository/releases?per_page=100\n'; }
pull_state_request() { printf 'GET\trepos/owner/repository/pulls?state=closed&base=main&per_page=100\n'; }
tag_ref_request() { printf 'GET\trepos/owner/repository/git/ref/tags/%s\n' "$1"; }
create_ref_request() { printf 'POST\trepos/owner/repository/git/refs\n'; }
notes_request() { printf 'POST\trepos/owner/repository/releases/generate-notes\n'; }
release_create_request() { printf 'POST\trepos/owner/repository/releases\n'; }
default_planning_requests() {
    target_context_requests
    release_state_request
    pull_state_request
    target_context_requests
    release_state_request
}
default_mutation_requests() {
    default_planning_requests
    release_state_request
}
successful_create_requests() {
    default_mutation_requests
    create_ref_request
    tag_ref_request 0.2.1
    notes_request
    tag_ref_request 0.2.1
    release_create_request
}
successful_resume_requests() {
    default_mutation_requests
    tag_ref_request 0.2.1
    notes_request
    tag_ref_request 0.2.1
    release_create_request
}

assert_workflow_line 'canonical CI path' \
    "      github.event.workflow.path == '.github/workflows/ci.yml' &&"
assert_workflow_line 'canonical CI identity binding' \
    '      github.event.workflow.id == github.event.workflow_run.workflow_id'
assert_workflow_line 'trusted current main checkout' '          ref: main'
# This is a literal rejected GitHub expression.
# shellcheck disable=SC2016
assert_workflow_absent 'historical target is not executable code' \
    'ref: ${{ github.event.workflow_run.head_sha }}'

setup_case create
precreate_target_tag
assert_fake_failure 'wrong GitHub header' api --paginate --slurp \
    -H 'Accept: application/json' \
    "repos/owner/repository/commits/$target_sha/pulls?per_page=100"
assert_fake_failure 'extra commit endpoint segment' api --paginate --slurp \
    -H 'Accept: application/vnd.github+json' \
    "repos/owner/repository/commits/$target_sha/extra/pulls?per_page=100"
assert_fake_failure 'wrong jq program' api \
    "repos/owner/repository/git/ref/tags/0.2.1" --jq '.object.sha'
assert_fake_failure 'extra tag endpoint prefix' api \
    'repos/owner/repository/git/ref/tags/extra/0.2.1' \
    --jq 'select(.object.type == "commit") | .object.sha'
assert_fake_failure 'wrong repository' api --paginate --slurp \
    'repos/other/repository/releases?per_page=100'
assert_fake_failure 'missing pagination contract' api \
    'repos/owner/repository/releases?per_page=100'
assert_fake_failure 'unexpected explicit GET method' api --method GET \
    --paginate --slurp 'repos/owner/repository/releases?per_page=100'
assert_fake_failure 'unexpected notes field' api --method POST \
    'repos/owner/repository/releases/generate-notes' \
    -f tag_name=0.2.1 -f target_commitish="$target_sha" \
    -f previous_tag_name=0.2.0 -f unexpected=value
assert_fake_failure 'missing notes field' api --method POST \
    'repos/owner/repository/releases/generate-notes' \
    -f tag_name=0.2.1 -f target_commitish="$target_sha"
assert_requests 'invalid fake requests are not traced' ''
teardown_case

setup_case no_label
capture_publisher
assert_run 'no label' 0 \
    'release publication: merged pull request has no release label' ''
assert_attempts 'no label' ''
assert_published 'no label' '0.2.0'
assert_remote_tag 'no label target' 0.2.1 ''
expected_requests=$(target_context_requests)
assert_requests 'no label' "$expected_requests"
teardown_case

setup_case stale_checkout
git -C "$case_repo" checkout -q --detach "$target_sha"
capture_publisher
assert_run 'historical checkout rejected' 1 '' \
    'release publication: checkout does not match current main'
assert_attempts 'historical checkout rejected' ''
assert_requests 'historical checkout rejected' ''
assert_published 'historical checkout rejected' '0.2.0'
assert_remote_tag 'historical checkout target' 0.2.1 ''
teardown_case

setup_case create
capture_publisher
assert_run 'create' 0 \
    '{"tag_name":"0.2.1","draft":false,"prerelease":false}' ''
expected_attempts=$(printf 'ref\t0.2.1\t%s\nrelease\t0.2.1' "$target_sha")
assert_attempts 'create' "$expected_attempts"
assert_published 'create' '0.2.0
0.2.1'
assert_remote_tag 'create target' 0.2.1 "$target_sha"
expected_requests=$(successful_create_requests)
assert_requests 'create' "$expected_requests"
teardown_case

setup_case resume
precreate_target_tag
capture_publisher
assert_run 'resume' 0 \
    '{"tag_name":"0.2.1","draft":false,"prerelease":false}' ''
assert_attempts 'resume' "$(printf 'release\t0.2.1')"
assert_published 'resume' '0.2.0
0.2.1'
assert_remote_tag 'resume target' 0.2.1 "$target_sha"
expected_requests=$(successful_resume_requests)
assert_requests 'resume' "$expected_requests"
teardown_case

setup_case noop
precreate_target_tag
printf '%s\n' 0.2.1 >>"$case_state/published.txt"
capture_publisher
assert_run 'noop' 0 '' ''
assert_attempts 'noop' ''
assert_published 'noop' '0.2.0
0.2.1'
assert_remote_tag 'noop target' 0.2.1 "$target_sha"
expected_requests=$(default_planning_requests)
assert_requests 'noop' "$expected_requests"
teardown_case

setup_case wait_refresh
capture_publisher
expected_stdout='release publication: waiting for PR #10
{"tag_name":"0.3.0","draft":false,"prerelease":false}'
assert_run 'wait refresh' 0 "$expected_stdout" ''
expected_attempts=$(printf 'sleep\t0\nref\t0.3.0\t%s\nrelease\t0.3.0' "$target_sha")
assert_attempts 'wait refresh' "$expected_attempts"
assert_published 'wait refresh' '0.2.0
0.2.1
0.3.0'
assert_remote_tag 'wait predecessor' 0.2.1 "$earlier_sha"
assert_remote_tag 'wait target' 0.3.0 "$target_sha"
expected_requests=$(
    target_context_requests
    release_state_request
    pull_state_request
    earlier_context_requests
    target_context_requests
    release_state_request
    release_state_request
    release_state_request
    create_ref_request
    tag_ref_request 0.3.0
    notes_request
    tag_ref_request 0.3.0
    release_create_request
)
assert_requests 'wait refresh' "$expected_requests"
teardown_case

setup_case conflict_422
capture_publisher
assert_run '422 recovery' 0 \
    '{"tag_name":"0.2.1","draft":false,"prerelease":false}' ''
expected_attempts=$(printf 'ref\t0.2.1\t%s\nrelease\t0.2.1' "$target_sha")
assert_attempts '422 recovery' "$expected_attempts"
assert_published '422 recovery' '0.2.0
0.2.1'
assert_remote_tag '422 target' 0.2.1 "$target_sha"
expected_requests=$(
    default_mutation_requests
    create_ref_request
    tag_ref_request 0.2.1
    release_state_request
    tag_ref_request 0.2.1
    notes_request
    tag_ref_request 0.2.1
    release_create_request
)
assert_requests '422 recovery' "$expected_requests"
teardown_case

setup_case other_422
capture_publisher
assert_run 'non-conflict 422' 1 '' 'gh: Validation Failed (HTTP 422)'
expected_attempts=$(printf 'ref\t0.2.1\t%s' "$target_sha")
assert_attempts 'non-conflict 422' "$expected_attempts"
assert_published 'non-conflict 422' '0.2.0'
assert_remote_tag 'non-conflict 422 target' 0.2.1 "$target_sha"
expected_requests=$(
    default_mutation_requests
    create_ref_request
)
assert_requests 'non-conflict 422' "$expected_requests"
teardown_case

setup_case conflict_other_sha
capture_publisher
expected_collision='release plan: tag is not owned by a merged PR: 0.2.1'
assert_run 'same-version collision elsewhere' 1 '' "$expected_collision"
expected_attempts=$(printf 'ref\t0.2.1\t%s' "$target_sha")
assert_attempts 'same-version collision elsewhere' "$expected_attempts"
assert_published 'same-version collision elsewhere' '0.2.0'
assert_remote_tag 'same-version collision elsewhere target' 0.2.1 "$earlier_sha"
expected_requests=$(
    default_mutation_requests
    create_ref_request
    tag_ref_request 0.2.1
    release_state_request
)
assert_requests 'same-version collision elsewhere' "$expected_requests"
teardown_case

setup_case non_422
capture_publisher
assert_run 'non-422 failure' 1 '' 'gh: Internal Server Error (HTTP 500)'
expected_attempts=$(printf 'ref\t0.2.1\t%s' "$target_sha")
assert_attempts 'non-422 failure' "$expected_attempts"
assert_published 'non-422 failure' '0.2.0'
assert_remote_tag 'non-422 target' 0.2.1 ''
expected_requests=$(
    default_mutation_requests
    create_ref_request
)
assert_requests 'non-422 failure' "$expected_requests"
teardown_case

setup_case release_failure_once
capture_publisher
assert_run 'first Release failure' 1 '' 'gh: Internal Server Error (HTTP 500)'
assert_published 'first Release failure' '0.2.0'
expected_requests=$(successful_create_requests)
assert_requests 'first Release failure' "$expected_requests"
capture_publisher
assert_run 'Release retry' 0 \
    '{"tag_name":"0.2.1","draft":false,"prerelease":false}' ''
expected_attempts=$(printf 'ref\t0.2.1\t%s\nrelease\t0.2.1\nrelease\t0.2.1' "$target_sha")
assert_attempts 'Release retry' "$expected_attempts"
assert_published 'Release retry' '0.2.0
0.2.1'
assert_remote_tag 'Release retry target' 0.2.1 "$target_sha"
expected_requests=$(
    successful_create_requests
    successful_resume_requests
)
assert_requests 'Release retry cumulative' "$expected_requests"
teardown_case

setup_case release_committed_failure
capture_publisher
assert_run 'committed Release response failure' 1 '' \
    'gh: Internal Server Error after commit (HTTP 500)'
assert_published 'committed Release response failure' '0.2.0
0.2.1'
expected_requests=$(successful_create_requests)
assert_requests 'committed Release response failure' "$expected_requests"
capture_publisher
assert_run 'committed Release reconciliation' 0 '' ''
expected_attempts=$(printf 'ref\t0.2.1\t%s\nrelease\t0.2.1' "$target_sha")
assert_attempts 'committed Release reconciliation' "$expected_attempts"
assert_published 'committed Release reconciliation' '0.2.0
0.2.1'
assert_remote_tag 'committed Release target' 0.2.1 "$target_sha"
expected_requests=$(
    successful_create_requests
    default_planning_requests
)
assert_requests 'committed Release reconciliation cumulative' "$expected_requests"
teardown_case

setup_case bad_merge_sha
capture_publisher
missing_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
expected_error="release publication: missing commit for merge SHA for PR #10: $missing_sha"
assert_run 'missing merge commit' 1 '' "$expected_error"
assert_attempts 'missing merge commit' ''
assert_published 'missing merge commit' '0.2.0'
expected_requests=$(
    target_context_requests
    release_state_request
    pull_state_request
)
assert_requests 'missing merge commit' "$expected_requests"
teardown_case

setup_case annotated_baseline
git -C "$case_repo" tag -d 0.2.0 >/dev/null
git -C "$case_repo" push -q origin :refs/tags/0.2.0
git -C "$case_repo" tag -a 0.2.0 "$baseline_sha" -m 0.2.0
git -C "$case_repo" push -q origin refs/tags/0.2.0
capture_publisher
assert_run 'annotated stable baseline' 1 '' \
    'release publication: stable tag is not lightweight: 0.2.0'
assert_attempts 'annotated stable baseline' ''
assert_published 'annotated stable baseline' '0.2.0'
expected_requests=$(target_context_requests)
assert_requests 'annotated stable baseline' "$expected_requests"
teardown_case

setup_case deleted_remote_baseline
git -C "$case_repo" push -q origin :refs/tags/0.2.0
capture_publisher
assert_run 'deleted remote baseline is pruned' 1 '' \
    'release publication: Release without tag: 0.2.0'
assert_attempts 'deleted remote baseline is pruned' ''
assert_published 'deleted remote baseline is pruned' '0.2.0'
assert_remote_tag 'deleted remote baseline' 0.2.0 ''
expected_requests=$(
    target_context_requests
    release_state_request
)
assert_requests 'deleted remote baseline is pruned' "$expected_requests"
teardown_case

setup_case delete_tag_before_verify
capture_publisher
assert_run 'tag deleted before Release' 1 '' \
    'release publication: remote tag is missing or not lightweight: 0.2.1'
expected_attempts=$(printf 'ref\t0.2.1\t%s' "$target_sha")
assert_attempts 'tag deleted before Release' "$expected_attempts"
assert_published 'tag deleted before Release' '0.2.0'
assert_remote_tag 'tag deleted before Release target' 0.2.1 ''
expected_requests=$(
    default_mutation_requests
    create_ref_request
    tag_ref_request 0.2.1
)
assert_requests 'tag deleted before Release' "$expected_requests"
teardown_case

setup_case move_tag_before_verify
capture_publisher
assert_run 'tag moved before Release' 1 '' \
    'release publication: remote tag does not match target SHA: 0.2.1'
expected_attempts=$(printf 'ref\t0.2.1\t%s' "$target_sha")
assert_attempts 'tag moved before Release' "$expected_attempts"
assert_published 'tag moved before Release' '0.2.0'
assert_remote_tag 'tag moved before Release target' 0.2.1 "$earlier_sha"
expected_requests=$(
    default_mutation_requests
    create_ref_request
    tag_ref_request 0.2.1
)
assert_requests 'tag moved before Release' "$expected_requests"
teardown_case

setup_case delete_tag_after_notes
capture_publisher
assert_run 'tag deleted after notes' 1 '' \
    'release publication: remote tag is missing or not lightweight: 0.2.1'
expected_attempts=$(printf 'ref\t0.2.1\t%s' "$target_sha")
assert_attempts 'tag deleted after notes' "$expected_attempts"
assert_published 'tag deleted after notes' '0.2.0'
assert_remote_tag 'tag deleted after notes target' 0.2.1 ''
expected_requests=$(
    default_mutation_requests
    create_ref_request
    tag_ref_request 0.2.1
    notes_request
    tag_ref_request 0.2.1
)
assert_requests 'tag deleted after notes' "$expected_requests"
teardown_case

setup_case move_tag_after_notes
capture_publisher
assert_run 'tag moved after notes' 1 '' \
    'release publication: remote tag does not match target SHA: 0.2.1'
expected_attempts=$(printf 'ref\t0.2.1\t%s' "$target_sha")
assert_attempts 'tag moved after notes' "$expected_attempts"
assert_published 'tag moved after notes' '0.2.0'
assert_remote_tag 'tag moved after notes target' 0.2.1 "$earlier_sha"
expected_requests=$(
    default_mutation_requests
    create_ref_request
    tag_ref_request 0.2.1
    notes_request
    tag_ref_request 0.2.1
)
assert_requests 'tag moved after notes' "$expected_requests"
teardown_case

setup_case invalid_notes_body
capture_publisher
assert_run 'invalid generated notes body' 1 '' \
    'release publication: generated notes body is not a string'
expected_attempts=$(printf 'ref\t0.2.1\t%s' "$target_sha")
assert_attempts 'invalid generated notes body' "$expected_attempts"
assert_published 'invalid generated notes body' '0.2.0'
assert_remote_tag 'invalid notes target' 0.2.1 "$target_sha"
expected_requests=$(
    default_mutation_requests
    create_ref_request
    tag_ref_request 0.2.1
    notes_request
)
assert_requests 'invalid generated notes body' "$expected_requests"
teardown_case

setup_case signal_term
capture_publisher
assert_run 'TERM cleanup' 143 \
    'release publication: waiting for PR #10' ''
assert_attempts 'TERM cleanup' "$(printf 'sleep\t0')"
assert_published 'TERM cleanup' '0.2.0'
assert_remote_tag 'TERM target' 0.3.0 ''
expected_requests=$(
    target_context_requests
    release_state_request
    pull_state_request
    earlier_context_requests
    target_context_requests
    release_state_request
)
assert_requests 'TERM cleanup' "$expected_requests"
teardown_case

printf '%s\n' 'publisher contract: OK'
