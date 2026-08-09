#!/bin/sh

set -eu

major=0
minor=0
patch=0
unsupported=0
merge_count=0
frozen_major=0
frozen_minor=0
frozen_patch=0
frozen_unsupported=0
tab=$(printf '\t')

while IFS= read -r record || [ -n "$record" ]; do
    case "$record" in
        merged"$tab"*)
            printf '%s\n' 'release timeline: malformed record' >&2
            exit 1
            ;;
        *"$tab"*"$tab"*)
            printf '%s\n' 'release timeline: malformed record' >&2
            exit 1
            ;;
    esac

    case "$record" in
        *"$tab"*)
            event=${record%%"$tab"*}
            label=${record#*"$tab"}
            ;;
        *)
            event=$record
            label=
            ;;
    esac

    case "$event" in
        labeled|unlabeled)
            [ -n "$label" ] || { printf '%s\n' 'release timeline: missing label' >&2; exit 1; }
            [ "$merge_count" -eq 0 ] || continue
            value=1
            [ "$event" = labeled ] || value=0
            case "$label" in
                semver:major) major=$value ;;
                semver:minor) minor=$value ;;
                semver:patch) patch=$value ;;
                semver:*)
                    if [ "$event" = labeled ]; then
                        unsupported=$((unsupported + 1))
                    elif [ "$unsupported" -gt 0 ]; then
                        unsupported=$((unsupported - 1))
                    fi
                    ;;
            esac
            ;;
        merged)
            [ -z "$label" ] || { printf '%s\n' 'release timeline: merged record has a label' >&2; exit 1; }
            merge_count=$((merge_count + 1))
            [ "$merge_count" -eq 1 ] || { printf '%s\n' 'release timeline: multiple merge boundaries' >&2; exit 1; }
            frozen_major=$major
            frozen_minor=$minor
            frozen_patch=$patch
            frozen_unsupported=$unsupported
            ;;
        *)
            printf '%s\n' "release timeline: unsupported event: $event" >&2
            exit 1
            ;;
    esac
done

[ "$merge_count" -eq 1 ] || { printf '%s\n' 'release timeline: missing merge boundary' >&2; exit 1; }
[ "$frozen_major" -eq 0 ] || printf '%s\n' 'semver:major'
[ "$frozen_minor" -eq 0 ] || printf '%s\n' 'semver:minor'
[ "$frozen_patch" -eq 0 ] || printf '%s\n' 'semver:patch'
[ "$frozen_unsupported" -eq 0 ] || printf '%s\n' 'semver:unsupported'
