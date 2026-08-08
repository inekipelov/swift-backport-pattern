#!/bin/sh

set -eu
: "${FAKE_RELEASE_SCENARIO:?}"
: "${FAKE_RELEASE_STATE_DIR:?}"
: "${FAKE_GIT_REPO:?}"
: "${FAKE_BASELINE_SHA:?}"
: "${FAKE_EARLIER_SHA:?}"
: "${FAKE_TARGET_SHA:?}"

method=GET
endpoint=
ref=
sha=
tag_name=
while [ "$#" -gt 0 ]; do
    case "$1" in
        api|--paginate|--slurp) shift ;;
        -H|--jq) shift 2 ;;
        --method) method=$2; shift 2 ;;
        -f|-F)
            assignment=$2
            key=${assignment%%=*}
            value=${assignment#*=}
            case "$key" in
                ref) ref=$value ;;
                sha) sha=$value ;;
                tag_name) tag_name=$value ;;
            esac
            shift 2
            ;;
        repos/*) endpoint=$1; shift ;;
        *) printf '%s\n' "fake release gh: unexpected argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$endpoint" ] || { printf '%s\n' 'fake release gh: missing endpoint' >&2; exit 2; }

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
print_releases() {
    jq -Rn '[inputs | select(length > 0) | {tag_name: ., draft: false, prerelease: false}]' \
        <"$FAKE_RELEASE_STATE_DIR/published.txt" | jq -s '.'
}

case "$method:$endpoint" in
    GET:*/commits/*/pulls\?per_page=100)
        commit_sha=${endpoint#*/commits/}
        commit_sha=${commit_sha%%/*}
        case "$commit_sha" in
            "$FAKE_TARGET_SHA") printf '[[%s]]\n' "$(print_pr 20 "$FAKE_TARGET_SHA")" ;;
            "$FAKE_EARLIER_SHA") printf '[[%s]]\n' "$(print_pr 10 "$FAKE_EARLIER_SHA")" ;;
            *) printf '%s\n' '[[]]' ;;
        esac
        ;;
    GET:*/issues/20/timeline\?per_page=100)
        case "$FAKE_RELEASE_SCENARIO" in
            no_label) printf '%s\n' '[[{"event":"merged"}]]' ;;
            wait_refresh) printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:minor"}},{"event":"merged"}]]' ;;
            *) printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}},{"event":"merged"}]]' ;;
        esac
        ;;
    GET:*/issues/10/timeline\?per_page=100)
        printf '%s\n' '[[{"event":"labeled","label":{"name":"semver:patch"}},{"event":"merged"}]]'
        ;;
    GET:*/pulls\?state=closed\&base=main\&per_page=100)
        case "$FAKE_RELEASE_SCENARIO" in
            wait_refresh)
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
    GET:*/releases\?per_page=100) print_releases ;;
    POST:*/git/refs)
        version=${ref#refs/tags/}
        printf 'ref\t%s\t%s\n' "$version" "$sha" >>"$FAKE_RELEASE_STATE_DIR/mutations.tsv"
        case "$FAKE_RELEASE_SCENARIO" in
            non_422)
                printf '%s\n' 'gh: Internal Server Error (HTTP 500)' >&2
                exit 1
                ;;
            conflict_422)
                create_lightweight_tag "$version" "$sha"
                printf '%s\n' 'gh: Reference already exists (HTTP 422)' >&2
                exit 1
                ;;
        esac
        create_lightweight_tag "$version" "$sha"
        printf '{"ref":"refs/tags/%s","object":{"type":"commit","sha":"%s"}}\n' "$version" "$sha"
        ;;
    GET:*/git/ref/tags/*)
        version=${endpoint##*/}
        git -C "$FAKE_GIT_REPO" rev-parse "refs/tags/$version^{commit}"
        ;;
    POST:*/releases/generate-notes)
        printf '%s\n' '{"body":"generated notes"}'
        ;;
    POST:*/releases)
        printf 'release\t%s\n' "$tag_name" >>"$FAKE_RELEASE_STATE_DIR/mutations.tsv"
        if [ "$FAKE_RELEASE_SCENARIO" = release_failure_once ] && \
            [ ! -e "$FAKE_RELEASE_STATE_DIR/release-failed-once" ]; then
            : >"$FAKE_RELEASE_STATE_DIR/release-failed-once"
            printf '%s\n' 'gh: Internal Server Error (HTTP 500)' >&2
            exit 1
        fi
        grep -Fqx "$tag_name" "$FAKE_RELEASE_STATE_DIR/published.txt" || \
            printf '%s\n' "$tag_name" >>"$FAKE_RELEASE_STATE_DIR/published.txt"
        printf '{"tag_name":"%s","draft":false,"prerelease":false}\n' "$tag_name"
        ;;
    *) printf '%s\n' "fake release gh: unexpected request: $method $endpoint" >&2; exit 2 ;;
esac
