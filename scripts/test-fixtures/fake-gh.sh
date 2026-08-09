#!/bin/sh

set -eu

: "${FAKE_GH_SCENARIO:?FAKE_GH_SCENARIO is required}"
: "${FAKE_TARGET_SHA:?FAKE_TARGET_SHA is required}"

[ "$#" -eq 6 ] || { printf '%s\n' 'fake gh: unexpected argument count' >&2; exit 2; }
[ "$1" = api ] || { printf '%s\n' 'fake gh: expected api subcommand' >&2; exit 2; }
[ "$2" = --paginate ] || { printf '%s\n' 'fake gh: expected --paginate' >&2; exit 2; }
[ "$3" = --slurp ] || { printf '%s\n' 'fake gh: expected --slurp' >&2; exit 2; }
[ "$4" = -H ] || { printf '%s\n' 'fake gh: expected -H' >&2; exit 2; }
[ "$5" = 'Accept: application/vnd.github+json' ] || {
    printf '%s\n' 'fake gh: unexpected Accept header' >&2
    exit 2
}
endpoint=$6
pulls_endpoint="repos/owner/repository/commits/$FAKE_TARGET_SHA/pulls?per_page=100"
timeline_endpoint='repos/owner/repository/issues/42/timeline?per_page=100'

case "$endpoint" in
    "$pulls_endpoint")
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
    "$timeline_endpoint")
        case "$FAKE_GH_SCENARIO" in
            timeline_failure) exit 1 ;;
            missing_merge)
                printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}}],[]]'
                ;;
            multiple_merge)
                printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}},{"event":"merged"}],[{"event":"merged"}]]'
                ;;
            one|multiple|mismatch)
                printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}}],[{"event":"merged"},{"event":"unlabeled","label":{"name":"semver:patch"}}]]'
                ;;
            *) printf '%s\n' 'fake gh: unexpected timeline request' >&2; exit 2 ;;
        esac
        ;;
    *) printf '%s\n' "fake gh: unexpected endpoint: $endpoint" >&2; exit 2 ;;
esac
