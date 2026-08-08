#!/bin/sh

set -eu
printf 'sleep\t%s\n' "$1" >>"$FAKE_RELEASE_STATE_DIR/mutations.tsv"
if [ "$FAKE_RELEASE_SCENARIO" = wait_refresh ] && \
    [ ! -e "$FAKE_RELEASE_STATE_DIR/wait-refreshed" ]; then
    git -C "$FAKE_GIT_REPO" tag 0.2.1 "$FAKE_EARLIER_SHA"
    git -C "$FAKE_GIT_REPO" push -q origin refs/tags/0.2.1
    printf '%s\n' 0.2.1 >>"$FAKE_RELEASE_STATE_DIR/published.txt"
    : >"$FAKE_RELEASE_STATE_DIR/wait-refreshed"
fi
