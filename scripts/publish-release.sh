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
write_tag_release_state() {
    : >"$tag_release_file"
    : >"$tag_file"

    git tag --list >"$all_tags_file"
    while IFS= read -r observed_version; do
        if printf '%s\n' "$observed_version" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'; then
            tag_type=$(git cat-file -t "refs/tags/$observed_version")
            [ "$tag_type" = commit ] || {
                printf '%s\n' "release publication: stable tag is not lightweight: $observed_version" >&2
                return 1
            }
            tag_sha=$(git rev-list -n 1 "$observed_version")
            if is_ancestor_checked "$tag_sha" "$main_sha"; then
                :
            else
                ancestry_status=$?
                [ "$ancestry_status" -eq 1 ] && \
                    printf '%s\n' "release publication: stable tag is not on main: $observed_version" >&2
                return 1
            fi
            printf 'tag\t%s\t%s\n' "$observed_version" "$tag_sha"
        fi
    done <"$all_tags_file" >"$tag_file"
    cat "$tag_file" >>"$tag_release_file"

    "$GH_BIN" api --paginate --slurp \
        "repos/$repository/releases?per_page=100" >"$releases_file"
    while IFS="$(printf '\t')" read -r observed_record observed_version observed_tag_sha; do
        release_state=$("$JQ_BIN" -r --arg version "$observed_version" '
          [add[] | select(.tag_name == $version)] |
          if length == 0 then "missing"
          elif length > 1 then "invalid"
          elif .[0].draft then "draft"
          elif .[0].prerelease then "prerelease"
          else "published"
          end
        ' "$releases_file")
        [ "$release_state" != invalid ] || {
            printf '%s\n' "release publication: duplicate Releases for $observed_version" >&2
            return 1
        }
        printf 'release\t%s\t%s\n' "$observed_version" "$release_state" >>"$tag_release_file"
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
cleanup_temporary_files() {
    rm -f "$state_file" "$plan_file" "$tag_file" "$all_tags_file" \
        "$releases_file" "$pulls_file" "$tag_release_file" \
        "$pr_state_file" "$release_versions_file" "$pull_rows_file" \
        "$ancestor_versions_file" "$tag_create_response" "$tag_create_error"
}

state_file=
plan_file=
tag_file=
all_tags_file=
releases_file=
pulls_file=
tag_release_file=
pr_state_file=
release_versions_file=
pull_rows_file=
ancestor_versions_file=
tag_create_response=
tag_create_error=
trap cleanup_temporary_files 0 1 2 15

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
