#!/bin/sh

LC_ALL=C
export LC_ALL

stable_pattern='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

component_gt() {
    left=$1
    right=$2
    [ "${#left}" -gt "${#right}" ] && return 0
    [ "${#left}" -lt "${#right}" ] && return 1
    LC_ALL=C expr "x$left" \> "x$right" >/dev/null
}

version_gt() {
    candidate=$1
    current=$2
    old_ifs=$IFS
    IFS=.
    set -- $candidate
    IFS=$old_ifs
    candidate_major=$1
    candidate_minor=$2
    candidate_patch=$3
    IFS=.
    set -- $current
    IFS=$old_ifs
    current_major=$1
    current_minor=$2
    current_patch=$3

    if [ "$candidate_major" != "$current_major" ]; then
        component_gt "$candidate_major" "$current_major"
        return
    fi
    if [ "$candidate_minor" != "$current_minor" ]; then
        component_gt "$candidate_minor" "$current_minor"
        return
    fi
    component_gt "$candidate_patch" "$current_patch"
}

latest=
while IFS= read -r tag || [ -n "$tag" ]; do
    printf '%s\n' "$tag" | grep -Eq "$stable_pattern" || continue
    if [ -z "$latest" ] || version_gt "$tag" "$latest"; then
        latest=$tag
    fi
done

[ -n "$latest" ] || {
    printf '%s\n' 'semver: no stable version tags found' >&2
    exit 1
}
printf '%s\n' "$latest"
