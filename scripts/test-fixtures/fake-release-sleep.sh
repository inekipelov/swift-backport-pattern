#!/bin/sh

set -eu
[ "$#" -eq 1 ] || { printf '%s\n' 'fake release sleep: expected one argument' >&2; exit 2; }
case "$1" in *[!0-9]*|'') printf '%s\n' 'fake release sleep: invalid duration' >&2; exit 2 ;; esac
printf 'sleep\t%s\n' "$1" >>"$FAKE_RELEASE_STATE_DIR/mutations.tsv"
if [ "$FAKE_RELEASE_SCENARIO" = signal_term ]; then
    kill -TERM "$PPID"
    exit 0
fi
if [ "$FAKE_RELEASE_SCENARIO" = wait_refresh ] && \
    [ ! -e "$FAKE_RELEASE_STATE_DIR/wait-refreshed" ]; then
    git -C "$FAKE_GIT_REPO" tag 0.2.1 "$FAKE_EARLIER_SHA"
    git -C "$FAKE_GIT_REPO" push -q origin refs/tags/0.2.1
    printf '%s\n' 0.2.1 >>"$FAKE_RELEASE_STATE_DIR/published.txt"
    : >"$FAKE_RELEASE_STATE_DIR/wait-refreshed"
fi
