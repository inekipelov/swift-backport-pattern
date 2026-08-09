#!/bin/sh

set -eu
: "${FAKE_RELEASE_SCENARIO:?}"
: "${FAKE_RELEASE_STATE_DIR:?}"
: "${FAKE_GIT_REPO:?}"
: "${FAKE_BASELINE_SHA:?}"
: "${FAKE_EARLIER_SHA:?}"
: "${FAKE_TARGET_SHA:?}"
: "${FAKE_CURRENT_SHA:?}"

fail_request() { printf '%s\n' "fake release gh: $1" >&2; exit 2; }
[ -n "${RUNNER_TEMP:-}" ] || fail_request 'RUNNER_TEMP is required'
[ "${TMPDIR:-}" = "$RUNNER_TEMP" ] || fail_request 'TMPDIR must equal RUNNER_TEMP'

[ "$#" -gt 0 ] && [ "$1" = api ] || fail_request 'expected api subcommand'
shift

method=GET
method_set=0
endpoint=
paginate=0
slurp=0
header=
header_set=0
jq_program=
jq_set=0
form_count=0
ref=; ref_set=0; ref_kind=
sha=; sha_set=0; sha_kind=
tag_name=; tag_name_set=0; tag_name_kind=
target_commitish=; target_commitish_set=0; target_commitish_kind=
previous_tag_name=; previous_tag_name_set=0; previous_tag_name_kind=
name=; name_set=0; name_kind=
body=; body_set=0; body_kind=
draft=; draft_set=0; draft_kind=
prerelease=; prerelease_set=0; prerelease_kind=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --paginate)
            [ "$paginate" -eq 0 ] || fail_request 'duplicate --paginate'
            paginate=1
            shift
            ;;
        --slurp)
            [ "$slurp" -eq 0 ] || fail_request 'duplicate --slurp'
            slurp=1
            shift
            ;;
        -H)
            [ "$#" -ge 2 ] || fail_request 'missing header value'
            [ "$header_set" -eq 0 ] || fail_request 'duplicate header'
            header=$2
            header_set=1
            shift 2
            ;;
        --jq)
            [ "$#" -ge 2 ] || fail_request 'missing jq program'
            [ "$jq_set" -eq 0 ] || fail_request 'duplicate jq program'
            jq_program=$2
            jq_set=1
            shift 2
            ;;
        --method)
            [ "$#" -ge 2 ] || fail_request 'missing method value'
            [ "$method_set" -eq 0 ] || fail_request 'duplicate method'
            method=$2
            method_set=1
            shift 2
            ;;
        -f|-F)
            [ "$#" -ge 2 ] || fail_request 'missing form assignment'
            form_kind=$1
            assignment=$2
            case "$assignment" in *=*) ;; *) fail_request 'invalid form assignment' ;; esac
            key=${assignment%%=*}
            value=${assignment#*=}
            case "$key" in
                ref)
                    [ "$ref_set" -eq 0 ] || fail_request 'duplicate ref field'
                    ref=$value; ref_set=1; ref_kind=$form_kind
                    ;;
                sha)
                    [ "$sha_set" -eq 0 ] || fail_request 'duplicate sha field'
                    sha=$value; sha_set=1; sha_kind=$form_kind
                    ;;
                tag_name)
                    [ "$tag_name_set" -eq 0 ] || fail_request 'duplicate tag_name field'
                    tag_name=$value; tag_name_set=1; tag_name_kind=$form_kind
                    ;;
                target_commitish)
                    [ "$target_commitish_set" -eq 0 ] || fail_request 'duplicate target_commitish field'
                    target_commitish=$value; target_commitish_set=1; target_commitish_kind=$form_kind
                    ;;
                previous_tag_name)
                    [ "$previous_tag_name_set" -eq 0 ] || fail_request 'duplicate previous_tag_name field'
                    previous_tag_name=$value; previous_tag_name_set=1; previous_tag_name_kind=$form_kind
                    ;;
                name)
                    [ "$name_set" -eq 0 ] || fail_request 'duplicate name field'
                    name=$value; name_set=1; name_kind=$form_kind
                    ;;
                body)
                    [ "$body_set" -eq 0 ] || fail_request 'duplicate body field'
                    body=$value; body_set=1; body_kind=$form_kind
                    ;;
                draft)
                    [ "$draft_set" -eq 0 ] || fail_request 'duplicate draft field'
                    draft=$value; draft_set=1; draft_kind=$form_kind
                    ;;
                prerelease)
                    [ "$prerelease_set" -eq 0 ] || fail_request 'duplicate prerelease field'
                    prerelease=$value; prerelease_set=1; prerelease_kind=$form_kind
                    ;;
                *) fail_request "unexpected form field: $key" ;;
            esac
            form_count=$((form_count + 1))
            shift 2
            ;;
        repos/*)
            [ -z "$endpoint" ] || fail_request 'multiple endpoints'
            endpoint=$1
            shift
            ;;
        *) fail_request "unexpected argument: $1" ;;
    esac
done
[ -n "$endpoint" ] || fail_request 'missing endpoint'

require_paginated_json() {
    [ "$method" = GET ] || fail_request 'unexpected method'
    [ "$method_set" -eq 0 ] || fail_request 'unexpected explicit method'
    [ "$paginate" -eq 1 ] && [ "$slurp" -eq 1 ] || fail_request 'missing pagination flags'
    [ "$jq_set" -eq 0 ] || fail_request 'unexpected jq program'
    [ "$form_count" -eq 0 ] || fail_request 'unexpected form fields'
}
require_post_base() {
    [ "$method" = POST ] || fail_request 'unexpected method'
    [ "$paginate" -eq 0 ] && [ "$slurp" -eq 0 ] || fail_request 'unexpected pagination flags'
    [ "$header_set" -eq 0 ] || fail_request 'unexpected header'
    [ "$jq_set" -eq 0 ] || fail_request 'unexpected jq program'
}
trace_request() { printf '%s\t%s\n' "$method" "$endpoint" >>"$FAKE_RELEASE_STATE_DIR/requests.tsv"; }
print_pr() {
    printf '{"number":%s,"merged_at":"2026-08-08T10:00:00Z","base":{"ref":"main"},"merge_commit_sha":"%s"}' "$1" "$2"
}
create_lightweight_tag() {
    version=$1
    commit_sha=$2
    if ! git -C "$FAKE_GIT_REPO" rev-parse -q --verify "refs/tags/$version" >/dev/null; then
        git -C "$FAKE_GIT_REPO" tag "$version" "$commit_sha"
        git -C "$FAKE_GIT_REPO" push -q origin "refs/tags/$version"
    fi
}
replace_lightweight_tag() {
    version=$1
    commit_sha=$2
    if git -C "$FAKE_GIT_REPO" rev-parse -q --verify "refs/tags/$version" >/dev/null; then
        git -C "$FAKE_GIT_REPO" tag -d "$version" >/dev/null
        git -C "$FAKE_GIT_REPO" push -q origin ":refs/tags/$version"
    fi
    git -C "$FAKE_GIT_REPO" tag "$version" "$commit_sha"
    git -C "$FAKE_GIT_REPO" push -q origin "refs/tags/$version"
}
delete_tag() {
    version=$1
    if git -C "$FAKE_GIT_REPO" rev-parse -q --verify "refs/tags/$version" >/dev/null; then
        git -C "$FAKE_GIT_REPO" tag -d "$version" >/dev/null
        git -C "$FAKE_GIT_REPO" push -q origin ":refs/tags/$version"
    fi
}
print_releases() {
    jq -Rn '[inputs | select(length > 0) | {tag_name: ., draft: false, prerelease: false}]' \
        <"$FAKE_RELEASE_STATE_DIR/published.txt" | jq -s '.'
}
publish_version() {
    version=$1
    grep -Fqx "$version" "$FAKE_RELEASE_STATE_DIR/published.txt" || \
        printf '%s\n' "$version" >>"$FAKE_RELEASE_STATE_DIR/published.txt"
}
expected_version() {
    case "$FAKE_RELEASE_SCENARIO" in wait_refresh|signal_term) printf '%s\n' 0.3.0 ;; *) printf '%s\n' 0.2.1 ;; esac
}
expected_previous() {
    case "$FAKE_RELEASE_SCENARIO" in wait_refresh|signal_term) printf '%s\n' 0.2.1 ;; *) printf '%s\n' 0.2.0 ;; esac
}

case "$method:$endpoint" in
    GET:repos/owner/repository/commits/*/pulls\?per_page=100)
        require_paginated_json
        [ "$header_set" -eq 1 ] && \
            [ "$header" = 'Accept: application/vnd.github+json' ] || \
            fail_request 'unexpected header'
        commit_sha=${endpoint#repos/owner/repository/commits/}
        commit_sha=${commit_sha%%/*}
        [ "$endpoint" = "repos/owner/repository/commits/$commit_sha/pulls?per_page=100" ] || \
            fail_request 'unexpected commit association endpoint'
        case "$commit_sha" in
            "$FAKE_TARGET_SHA"|"$FAKE_EARLIER_SHA") ;;
            *) fail_request 'unexpected commit association SHA' ;;
        esac
        trace_request
        case "$commit_sha" in
            "$FAKE_TARGET_SHA") printf '[[%s]]\n' "$(print_pr 20 "$FAKE_TARGET_SHA")" ;;
            "$FAKE_EARLIER_SHA") printf '[[%s]]\n' "$(print_pr 10 "$FAKE_EARLIER_SHA")" ;;
        esac
        ;;
    GET:repos/owner/repository/issues/20/timeline\?per_page=100)
        require_paginated_json
        [ "$header_set" -eq 1 ] && \
            [ "$header" = 'Accept: application/vnd.github+json' ] || \
            fail_request 'unexpected header'
        trace_request
        case "$FAKE_RELEASE_SCENARIO" in
            no_label) printf '%s\n' '[[{"event":"merged"}]]' ;;
            wait_refresh|signal_term)
                printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:minor"}},{"event":"merged"}]]'
                ;;
            *) printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}},{"event":"merged"}]]' ;;
        esac
        ;;
    GET:repos/owner/repository/issues/10/timeline\?per_page=100)
        require_paginated_json
        [ "$header_set" -eq 1 ] && \
            [ "$header" = 'Accept: application/vnd.github+json' ] || \
            fail_request 'unexpected header'
        trace_request
        printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}},{"event":"merged"}]]'
        ;;
    GET:repos/owner/repository/pulls\?state=closed\&base=main\&per_page=100)
        require_paginated_json
        [ "$header_set" -eq 0 ] || fail_request 'unexpected header'
        trace_request
        case "$FAKE_RELEASE_SCENARIO" in
            wait_refresh|signal_term)
                printf '[[%s,%s]]\n' "$(print_pr 10 "$FAKE_EARLIER_SHA")" "$(print_pr 20 "$FAKE_TARGET_SHA")"
                ;;
            bad_merge_sha)
                printf '[[%s,%s]]\n' \
                    "$(print_pr 10 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb)" \
                    "$(print_pr 20 "$FAKE_TARGET_SHA")"
                ;;
            *) printf '[[%s]]\n' "$(print_pr 20 "$FAKE_TARGET_SHA")" ;;
        esac
        ;;
    GET:repos/owner/repository/releases\?per_page=100)
        require_paginated_json
        [ "$header_set" -eq 0 ] || fail_request 'unexpected header'
        trace_request
        print_releases
        ;;
    GET:repos/owner/repository/git/ref/tags/*)
        [ "$method_set" -eq 0 ] || fail_request 'unexpected explicit method'
        [ "$paginate" -eq 0 ] && [ "$slurp" -eq 0 ] || fail_request 'unexpected pagination flags'
        [ "$header_set" -eq 0 ] || fail_request 'unexpected header'
        [ "$form_count" -eq 0 ] || fail_request 'unexpected form fields'
        [ "$jq_set" -eq 1 ] && \
            [ "$jq_program" = 'select(.object.type == "commit") | .object.sha' ] || \
            fail_request 'unexpected jq program'
        version=${endpoint#repos/owner/repository/git/ref/tags/}
        [ "$endpoint" = "repos/owner/repository/git/ref/tags/$version" ] || \
            fail_request 'unexpected tag endpoint'
        [ "$version" = "$(expected_version)" ] || fail_request 'unexpected tag version'
        trace_request
        case "$FAKE_RELEASE_SCENARIO" in
            delete_tag_before_verify)
                delete_tag "$version"
                printf '%s\n' 'gh: Not Found (HTTP 404)' >&2
                exit 1
                ;;
            move_tag_before_verify) replace_lightweight_tag "$version" "$FAKE_EARLIER_SHA" ;;
            delete_tag_after_notes)
                if [ -e "$FAKE_RELEASE_STATE_DIR/notes-generated" ]; then
                    delete_tag "$version"
                    printf '%s\n' 'gh: Not Found (HTTP 404)' >&2
                    exit 1
                fi
                ;;
            move_tag_after_notes)
                if [ -e "$FAKE_RELEASE_STATE_DIR/notes-generated" ]; then
                    replace_lightweight_tag "$version" "$FAKE_EARLIER_SHA"
                fi
                ;;
        esac
        tag_type=$(git -C "$FAKE_GIT_REPO" cat-file -t "refs/tags/$version" 2>/dev/null) || exit 1
        [ "$tag_type" = commit ] || exit 0
        git -C "$FAKE_GIT_REPO" rev-parse "refs/tags/$version"
        ;;
    POST:repos/owner/repository/git/refs)
        require_post_base
        [ "$form_count" -eq 2 ] && [ "$ref_set" -eq 1 ] && [ "$sha_set" -eq 1 ] || \
            fail_request 'unexpected ref form fields'
        [ "$ref_kind" = -f ] && [ "$sha_kind" = -f ] || fail_request 'unexpected ref form kind'
        version=${ref#refs/tags/}
        [ "$ref" = "refs/tags/$(expected_version)" ] || fail_request 'unexpected ref value'
        [ "$sha" = "$FAKE_TARGET_SHA" ] || fail_request 'unexpected ref SHA'
        trace_request
        printf 'ref\t%s\t%s\n' "$version" "$sha" >>"$FAKE_RELEASE_STATE_DIR/mutations.tsv"
        case "$FAKE_RELEASE_SCENARIO" in
            non_422)
                printf '%s\n' 'gh: Internal Server Error (HTTP 500)' >&2
                exit 1
                ;;
            other_422)
                create_lightweight_tag "$version" "$sha"
                printf '%s\n' 'gh: Validation Failed (HTTP 422)' >&2
                exit 1
                ;;
            conflict_422)
                create_lightweight_tag "$version" "$sha"
                printf '%s\n' 'gh: Reference already exists (HTTP 422)' >&2
                exit 1
                ;;
            conflict_other_sha)
                create_lightweight_tag "$version" "$FAKE_EARLIER_SHA"
                printf '%s\n' 'gh: Reference already exists (HTTP 422)' >&2
                exit 1
                ;;
        esac
        create_lightweight_tag "$version" "$sha"
        printf '{"ref":"refs/tags/%s","object":{"type":"commit","sha":"%s"}}\n' "$version" "$sha"
        ;;
    POST:repos/owner/repository/releases/generate-notes)
        require_post_base
        [ "$form_count" -eq 3 ] && [ "$tag_name_set" -eq 1 ] && \
            [ "$target_commitish_set" -eq 1 ] && [ "$previous_tag_name_set" -eq 1 ] || \
            fail_request 'unexpected notes form fields'
        [ "$tag_name_kind" = -f ] && [ "$target_commitish_kind" = -f ] && \
            [ "$previous_tag_name_kind" = -f ] || fail_request 'unexpected notes form kind'
        [ "$tag_name" = "$(expected_version)" ] || fail_request 'unexpected notes tag_name'
        [ "$target_commitish" = "$FAKE_TARGET_SHA" ] || fail_request 'unexpected notes target_commitish'
        [ "$previous_tag_name" = "$(expected_previous)" ] || fail_request 'unexpected notes previous_tag_name'
        trace_request
        case "$FAKE_RELEASE_SCENARIO" in
            invalid_notes_body) printf '%s\n' '{"body":null}' ;;
            *)
                : >"$FAKE_RELEASE_STATE_DIR/notes-generated"
                printf '%s\n' '{"body":"generated notes"}'
                ;;
        esac
        ;;
    POST:repos/owner/repository/releases)
        require_post_base
        [ "$form_count" -eq 6 ] && [ "$tag_name_set" -eq 1 ] && \
            [ "$target_commitish_set" -eq 1 ] && [ "$name_set" -eq 1 ] && \
            [ "$body_set" -eq 1 ] && [ "$draft_set" -eq 1 ] && \
            [ "$prerelease_set" -eq 1 ] || fail_request 'unexpected Release form fields'
        [ "$tag_name_kind" = -f ] && [ "$target_commitish_kind" = -f ] && \
            [ "$name_kind" = -f ] && [ "$body_kind" = -f ] && \
            [ "$draft_kind" = -F ] && [ "$prerelease_kind" = -F ] || \
            fail_request 'unexpected Release form kind'
        [ "$tag_name" = "$(expected_version)" ] || fail_request 'unexpected Release tag_name'
        [ "$target_commitish" = "$FAKE_TARGET_SHA" ] || fail_request 'unexpected Release target_commitish'
        [ "$name" = "$tag_name" ] || fail_request 'unexpected Release name'
        [ "$body" = 'generated notes' ] || fail_request 'unexpected Release body'
        [ "$draft" = false ] && [ "$prerelease" = false ] || fail_request 'unexpected Release flags'
        trace_request
        printf 'release\t%s\n' "$tag_name" >>"$FAKE_RELEASE_STATE_DIR/mutations.tsv"
        if [ "$FAKE_RELEASE_SCENARIO" = release_failure_once ] && \
            [ ! -e "$FAKE_RELEASE_STATE_DIR/release-failed-once" ]; then
            : >"$FAKE_RELEASE_STATE_DIR/release-failed-once"
            printf '%s\n' 'gh: Internal Server Error (HTTP 500)' >&2
            exit 1
        fi
        if [ "$FAKE_RELEASE_SCENARIO" = release_committed_failure ] && \
            [ ! -e "$FAKE_RELEASE_STATE_DIR/release-failed-after-commit" ]; then
            publish_version "$tag_name"
            : >"$FAKE_RELEASE_STATE_DIR/release-failed-after-commit"
            printf '%s\n' 'gh: Internal Server Error after commit (HTTP 500)' >&2
            exit 1
        fi
        publish_version "$tag_name"
        printf '{"tag_name":"%s","draft":false,"prerelease":false}\n' "$tag_name"
        ;;
    *) fail_request "unexpected request: $method $endpoint" ;;
esac
