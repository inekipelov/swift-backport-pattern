#!/bin/sh

set -eu

selected=

while IFS= read -r label || [ -n "$label" ]; do
    case "$label" in
        semver:major) bump=major ;;
        semver:minor) bump=minor ;;
        semver:patch) bump=patch ;;
        semver:*)
            printf '%s\n' "release labels: unsupported label: $label" >&2
            exit 1
            ;;
        *) continue ;;
    esac

    if [ -n "$selected" ]; then
        printf '%s\n' "release labels: multiple release labels: $selected and $bump" >&2
        exit 1
    fi
    selected=$bump
done

printf '%s\n' "$selected"
