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
canonical_version() {
    validated_version=$(printf '%s\n' "$1" | \
        sh "$script_dir/latest-stable-version.sh" 2>/dev/null) || return 1
    [ "$validated_version" = "$1" ]
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
record_shape_error=$(awk -F '\t' '
    $1 == "pr" && NF != 4 { print "malformed pr record at line " NR; exit }
    $1 == "tag" && NF != 3 { print "malformed tag record at line " NR; exit }
    $1 == "release" && NF != 3 { print "malformed release record at line " NR; exit }
' "$state_file")
[ -z "$record_shape_error" ] || fail_state "$record_shape_error"

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
            canonical_version "$one" || fail_state "invalid stable tag at line $line_number: $one"
            validate_sha "$two" "tag SHA at line $line_number"
            require_commit "$two" "tag SHA at line $line_number"
            printf '%s\t%s\n' "$one" "$two" >>"$tag_file"
            ;;
        release)
            [ -n "${one:-}" ] && [ -n "${two:-}" ] && [ -z "${three:-}" ] || \
                fail_state "malformed release record at line $line_number"
            canonical_version "$one" || fail_state "invalid Release version at line $line_number: $one"
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

candidate_sha=$(tag_sha_for "$expected_target_version")
[ -z "$candidate_sha" ] || fail_state "candidate version already belongs to $candidate_sha"
while IFS="$tab" read -r version tag_sha; do
    [ "$tag_sha" != "$target_sha" ] || continue
    if is_ancestor "$target_sha" "$tag_sha"; then
        fail_state "cannot create release before descendant tag: $version"
    fi
done <"$tag_file"
emit_plan create "$current_version" "$expected_target_version" ''
