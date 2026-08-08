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
