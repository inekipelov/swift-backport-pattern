#!/bin/sh

[ "$#" -eq 2 ] || { printf '%s\n' 'usage: next-semver.sh VERSION BUMP' >&2; exit 2; }

stable_pattern='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
case "$1" in
    *'
'*)
        printf '%s\n' "semver: invalid stable version: $1" >&2
        exit 1
        ;;
esac
printf '%s\n' "$1" | grep -Eq "$stable_pattern" || {
    printf '%s\n' "semver: invalid stable version: $1" >&2
    exit 1
}

decimal_increment() {
    digits=$1
    result=
    carry=1
    while [ -n "$digits" ]; do
        prefix=${digits%?}
        digit=${digits#"$prefix"}
        if [ "$carry" -eq 1 ]; then
            case "$digit" in
                0) digit=1; carry=0 ;; 1) digit=2; carry=0 ;;
                2) digit=3; carry=0 ;; 3) digit=4; carry=0 ;;
                4) digit=5; carry=0 ;; 5) digit=6; carry=0 ;;
                6) digit=7; carry=0 ;; 7) digit=8; carry=0 ;;
                8) digit=9; carry=0 ;; 9) digit=0 ;;
            esac
        fi
        result=$digit$result
        digits=$prefix
    done
    [ "$carry" -eq 0 ] || result=1$result
    printf '%s\n' "$result"
}

version=$1
bump=$2
old_ifs=$IFS
IFS=.
set -- $version
IFS=$old_ifs
major=$1
minor=$2
patch=$3

case "$bump" in
    major) major=$(decimal_increment "$major"); minor=0; patch=0 ;;
    minor) minor=$(decimal_increment "$minor"); patch=0 ;;
    patch) patch=$(decimal_increment "$patch") ;;
    *) printf '%s\n' "semver: unsupported bump: $bump" >&2; exit 1 ;;
esac
printf '%s.%s.%s\n' "$major" "$minor" "$patch"
