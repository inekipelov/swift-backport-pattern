# Releasing

This guide is the canonical release contract for maintainers, contributors,
and AI agents. It covers stable GitHub Releases produced from pull requests
merged into `main`.

## Release Authorization

Exactly three labels can authorize a stable release:

| Label | Result from `0.2.0` |
| --- | --- |
| `semver:major` | `1.0.0` |
| `semver:minor` | `0.3.0` |
| `semver:patch` | `0.2.1` |

No SemVer label is the normal no-release mode. Exactly one supported label
authorizes automatic publication after merge and successful push CI; no
additional confirmation occurs at publication time. More than one supported
label or any unsupported `semver:*` label fails closed. Commit text never
selects a version.

The labels active at the pull request's `merged` timeline event are
authoritative. Later edits to the closed pull request cannot create, suppress,
or change its release.

Applying or removing a release label changes release authorization. A human
must explicitly authorize an AI agent before the agent changes one of these
labels or any other release state.

## Version Calculation

Tags are unprefixed, lightweight, stable `X.Y.Z` refs. Prerelease identifiers
and build metadata are outside this policy. Version components are compared
numerically:

- `semver:patch`: `0.2.0 -> 0.2.1`;
- `semver:minor`: `0.2.0 -> 0.3.0`;
- `semver:major`: `0.2.0 -> 1.0.0`.

The predecessor must be a published stable Release on the protected `main`
ancestry. Tags are never overwritten or force-pushed.

## CI and Publication Boundary

`.github/workflows/ci.yml` is read-only. Its required checks are
`release-label` and `build-and-test`. Build and test share one SwiftPM build:
`swift build --build-tests` compiles sources and tests, then
`swift test --skip-build` runs the existing test bundle. Gitlint remains a
local Conventional Commit rule and is not a GitHub Actions check.

The release workflow accepts only a successful push run for `main` from the
exact canonical `.github/workflows/ci.yml`. It binds the triggering workflow's
path and workflow ID before granting its release job `contents: write`.

Release workflow code and `scripts/publish-release.sh` execute from the current
trusted `main` checkout. `workflow_run.head_sha` is passed only as
`TARGET_SHA`, the historical release target; that SHA is never checked out or
executed. The publisher freshly fetches `origin/main`, requires the trusted
checkout to equal it, and requires the target to exist and remain its ancestor.
It consumes no artifacts or caches from the triggering workflow.

Before entering mutation, publication revalidates the associated pull request,
merge SHA, merge-time label, Git ancestry, tags, Release state, and complete
release plan. Tag state is refreshed with pruning. Immediately before creating
a GitHub Release, the publisher verifies through GitHub that the exact remote
tag is lightweight and still points to `TARGET_SHA`.

## Generated Release Notes

GitHub generates notes from the preceding stable tag. Major, minor, and patch
pull requests appear under Breaking Changes, New Features, and Fixes.
Unlabeled pull requests since the predecessor appear under Other Changes.
Historical Release descriptions are not regenerated.

## Ordering and Retries

Every qualifying merge has its own idempotent release run. A later merge waits
up to 15 minutes while an earlier qualifying ancestor is unpublished. Ordering
comes from Git ancestry, not workflow queue order, pull request number, API
order, or timestamps. Tags and Releases are refreshed after every wait and
again immediately before mutation.

A completed old rerun is a no-op even when newer descendant Releases exist. A
partial target tag can be resumed only when it is the highest stable tag and is
the exact approved bump from a published predecessor.

If concurrent publication reports HTTP 422 while creating a tag, recovery is
allowed only when GitHub reports that the reference already exists. The
publisher then refreshes all state and requires the new plan's `action`,
`previous`, and `version` to remain consistent with the approved plan. Every
other 422 response fails without entering recovery.

## Failure Recovery

If tag creation succeeds and Release creation fails, rerun the failed Release
workflow. The rerun verifies the existing lightweight tag at the exact target
SHA and creates only the missing Release. If both already exist consistently,
the rerun performs no write.

A wrong tag owner, wrong bump, missing predecessor, draft or prerelease state,
divergent tag, ambiguous pull request, or bounded-wait timeout requires human
investigation. Automation never rewrites history. Correct the underlying
repository state only through a separately reviewed and explicitly authorized
change; do not move or force-push a stable tag.

## Permissions and Human Authority

The repository `GITHUB_TOKEN` creates tags and Releases; no personal token is
required. CI is read-only, and only the trusted Release job receives
`contents: write`. Selecting exactly one SemVer label is the human
authorization for automatic publication after merge; merging the pull request
does not require another release prompt.

An AI agent may add or remove a release label, rerun a release, or otherwise
change release state only after explicit human authorization. Merge still
requires the repository's independent review rules.

## Verification Boundary

Offline contract tests cover labels, merge timelines, SemVer, ancestry,
ordering, retries, API failures, and tag or Release mutations with disposable
Git repositories and fake GitHub commands. Pull request CI covers
documentation, compilation, and tests without write permission.

The first future merge carrying exactly one supported `semver:*` label is the
first production end-to-end publication test. Report that path as unverified
until it occurs.
