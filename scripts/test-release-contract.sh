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

if [ "$failures" -ne 0 ]; then
    exit 1
fi

printf '%s\n' 'release contract: OK'
