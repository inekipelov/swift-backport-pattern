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
assert_failure 'unsupported bump' sh scripts/next-semver.sh 1.2.3 build

latest=$(printf '%s\n' 0.9.9 0.10.0 01.0.0 v9.0.0 1.0.0-rc.1 notes 2.0.0+build | sh scripts/latest-stable-version.sh)
assert_equal 'numeric stable maximum' '0.10.0' "$latest"
assert_failure 'missing stable baseline' sh -c "printf '%s\n' v1.0.0 1.0.0-rc.1 | sh scripts/latest-stable-version.sh"

if [ "$failures" -ne 0 ]; then
    exit 1
fi

printf '%s\n' 'release contract: OK'
