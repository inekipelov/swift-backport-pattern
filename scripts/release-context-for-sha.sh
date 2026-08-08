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
