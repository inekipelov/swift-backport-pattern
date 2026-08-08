# SemVer Release Automation Design

## Goal

Replace the repository's split Build, Test, and Gitlint workflows with one
read-only CI workflow that compiles the Swift package and its tests once and
presents readable GitHub annotations. A separate trusted publication workflow
creates stable SemVer releases only after the successful `main` push CI for a
merged pull request that explicitly authorized a version bump through one
label.

The workflow must make ordinary merges safe: a pull request without a SemVer
label runs the complete merge gate but never creates a tag or GitHub Release.

## Current State

The repository currently runs three independent workflows:

- `.github/workflows/build.yml` executes `swift build -v`;
- `.github/workflows/test.yml` validates documentation and executes
  `swift test -v`;
- `.github/workflows/gitlint.yml` installs Gitlint and validates commits.

Build and Test run in separate macOS jobs, so they cannot share SwiftPM's
`.build` directory. The package is dependency-free and has no Xcode project or
workspace that should replace its SwiftPM build contract.

The published stable release line uses unprefixed tags. Existing tags and
GitHub Releases are `0.1.0`, `0.1.1`, `0.1.2`, and `0.2.0`. They remain
historical records and will not be renamed, rewritten, or regenerated.

## Release Contract

Three repository labels are the only release controls:

| Label | Meaning | Example from `0.2.0` |
| --- | --- | --- |
| `semver:major` | Increment the major component and reset minor and patch | `1.0.0` |
| `semver:minor` | Increment the minor component and reset patch | `0.3.0` |
| `semver:patch` | Increment the patch component | `0.2.1` |

The labels control stable releases only. Pre-release identifiers such as
`alpha`, `beta`, and `rc` are outside this contract.

For every pull request targeting `main`:

- zero SemVer labels is valid and means "merge without a release";
- exactly one SemVer label is valid and authorizes the corresponding release
  immediately after merge;
- more than one SemVer label is invalid and blocks merge through a required CI
  check.

Commit titles and bodies do not infer a version bump. `.gitlint` and the local
Conventional Commit convention remain contributor guidance, but Gitlint is no
longer a GitHub Actions check or a required merge status.

## Repository Label Set

The repository will contain only these labels:

| Label | Color | Description |
| --- | --- | --- |
| `semver:major` | `d73a4a` | Publish the next stable major release after merge |
| `semver:minor` | `1d76db` | Publish the next stable minor release after merge |
| `semver:patch` | `0e8a16` | Publish the next stable patch release after merge |

The current audit found the default label definitions `bug`, `documentation`,
`duplicate`, `enhancement`, `good first issue`, `help wanted`, `invalid`,
`question`, and `wontfix`. Before the mutation, automation must re-read the live
label set and build an exact delete list containing every name outside the
three-label allowlist, including any label added after the audit. It must also
inspect assignments on open and closed issues and pull requests. An unexpected
assignment stops the mutation for review rather than silently erasing
historical metadata. Label and assignment reads must use complete API
pagination. After creating or updating the three allowed labels, automation
must immediately repeat the full audit, require that the reviewed delete set
has not drifted, and recheck every target for assignments immediately before
deleting it. After deletion, the fully paginated live label set must equal the
allowlist exactly. Any concurrent drift aborts the operation; the labels API
does not provide an atomic bulk transaction.

Deleting label definitions is not delegated to the release workflow; it is a
one-time, reviewed repository configuration change.

No `release:none` label is added because absence of a `semver:*` label already
expresses that state without requiring maintainers to label every pull request.

## CI and Publication Workflows

`.github/workflows/ci.yml` replaces `build.yml`, `test.yml`, and `gitlint.yml`.
It runs for `pull_request` events targeting `main` with the `opened`,
`synchronize`, `reopened`, `labeled`, and `unlabeled` activity types, and for
`push` events on `main`. Including label activity ensures the merge gate always
evaluates the pull request's current release intent instead of preserving an
earlier successful result.

Pull request runs use a per-pull-request concurrency group and cancel an older
run when a newer commit or label event arrives. Push runs are not cancelled by
newer pushes. The workflow contains the `release-label` and `build-and-test`
jobs and has no write permission.

`.github/workflows/release.yml` is a separate privileged workflow triggered by
the `completed` `workflow_run` event for CI on `main`. Its release job runs only
when the triggering workflow used the `push` event, concluded successfully,
came from this repository's `main` branch, and identifies the exact trusted
head SHA. It never runs for pull request CI, consumes no artifacts or caches
from the triggering workflow, and never checks out a pull request head.

### `release-label`

On a pull request, the job reads the event's labels, counts the three supported
SemVer labels, and succeeds for zero or one label. It fails for multiple labels.

On a push to `main`, the job queries GitHub's commit-associated pull request
endpoint for `github.sha`. It considers merged pull requests targeting `main`:

- no associated merged pull request produces an empty bump and no release;
- exactly one associated merged pull request has its issue timeline replayed
  through the `merged` event, then produces `major`, `minor`, `patch`, or an
  empty bump from the labels active at that point;
- multiple matching pull requests fail as ambiguous rather than guessing which
  labels authorize publication.

Reconstructing the merge-time label set means later edits to the closed pull
request cannot create, suppress, or change a release. A missing `merged` event
or incomplete paginated timeline fails validation rather than falling back to
mutable current labels.

This also makes a prohibited direct push fail safe: CI still runs, but the
commit cannot accidentally publish a release. The job receives only
`contents: read`, `issues: read`, and `pull-requests: read` permissions.

### `build-and-test`

The job runs on the fixed `macos-15` runner label instead of mutable
`macos-latest` and uses an immutable commit SHA for `actions/checkout`. It
performs these steps in one job and one SwiftPM build configuration:

1. Assert that the runner provides the required tools and record `sw_vers`,
   Xcode, Swift, `xcbeautify`, Git, and `jq` versions.
2. Run `sh scripts/validate-documentation.sh`.
3. Run `sh scripts/test-release-contract.sh`.
4. Run `sh scripts/test-publish-release.sh` against disposable local Git
   repositories and fake GitHub/sleep adapters.
5. Compile package sources and the test bundle once:

   ```sh
   set -o pipefail
   swift build --build-tests 2>&1 | xcbeautify --renderer github-actions
   ```

6. Execute the already-built test bundle without recompilation:

   ```sh
   set -o pipefail
   swift test --skip-build 2>&1 | xcbeautify --renderer github-actions --is-ci
   ```

`pipefail` preserves the Swift command's failure status while `xcbeautify`
turns SwiftPM diagnostics into concise GitHub Actions output and annotations.
`xcpretty` is not used because this repository builds with SwiftPM rather than
an Xcode project, while `xcbeautify` explicitly accepts Swift build and test
output.

The workflow does not persist `.build` across workflow runs. Reuse inside the
single job removes duplicate compilation without introducing compiled-artifact
cache invalidation across changing runner images, Xcode versions, or Swift
toolchains. The package has no dependency download cache to preserve.

`macos-15`, its default Xcode toolchain, and its preinstalled `xcbeautify` are
maintained runner-image inputs, not immutable binaries. The workflow records
`sw_vers`, `xcodebuild -version`, `swift --version`, and `xcbeautify --version`
so drift is visible in every run. Exact toolchain pinning and a downloaded
formatter binary are intentionally avoided because the package should remain
compatible with the maintained runner and formatting does not alter build
semantics; a future reproducibility requirement would change that trade-off.

### `release`

The release job exists only in `.github/workflows/release.yml`. A successful CI
`workflow_run` for a push to `main` is its publication gate for the exact
`github.event.workflow_run.head_sha`. The job independently reconstructs the
associated pull request's merge-time labels and exits successfully without
write operations when the validated bump is empty. Pull request runs therefore
never receive publication permission.

The job runs on the fixed `ubuntu-24.04` runner label, receives
`contents: write`, `issues: read`, and `pull-requests: read`, and fetches the
complete tag history. It then:

1. Revalidates the merge-time label decision and identifies the pull request's
   `merge_commit_sha`, which GitHub defines as the commit that updated the base
   branch for merge, squash, and rebase merge methods. The value must equal
   `github.event.workflow_run.head_sha`; otherwise publication fails rather
   than tagging an unverified commit.
2. Finds strict stable `X.Y.Z` tags that already point to that commit.
3. Fails if more than one stable tag points to the commit.
4. If one stable tag and its GitHub Release already point to the commit,
   validates that its numeric predecessor is a published stable Release on the
   same strict `main` ancestry, validates every intervening qualifying pull
   request, and exits successfully as a completed retry, even when newer
   descendant releases now exist.
5. If one stable tag points to the commit but its GitHub Release is missing,
   treats it as a partial retry candidate: it must be the numerically highest
   stable tag and must equal the approved bump from the preceding stable tag,
   which must already have a published GitHub Release.
6. If no stable tag points to the commit, selects the numerically highest
   published stable tag that is a strict ancestor as the initial baseline,
   then checks merged pull requests after that baseline through the target. It
   uses paginated merged-pull-request data and Git ancestry, not API return
   order. A consistent higher tag without its Release on an earlier qualifying
   ancestor is pending and causes `wait`; an unexpected higher tag, wrong bump,
   divergent tag, or draft/prerelease state fails. Any earlier pull request
   carrying a valid SemVer label at merge must reach a consistent published
   release before the target can publish. The job polls this condition for up
   to 15 minutes, then fails with the blocking pull request and expected
   recovery action instead of publishing out of order.
7. After the predecessor wait, force-refreshes remote tags, re-reads GitHub
   Releases, and repeats the release-state checks so version calculation never
   uses a stale runner checkout.
8. Uses the rolling published predecessor established by the ancestry scan,
   verifies its tag and GitHub Release again, then computes the next version
   with a deterministic repository shell script.
9. Creates and pushes an unprefixed lightweight tag on the exact verified
   commit when the candidate is absent, preserving the repository's existing
   tag style.
10. Immediately publishes a GitHub Release whose tag and title are the computed
   version, using generated notes from the preceding stable tag.

The release job never rebuilds the package: the successful triggering CI
workflow is the publication gate for the exact head SHA.

## Generated Release Notes

`.github/release.yml` defines the generated changelog categories:

- **Breaking Changes** for `semver:major`;
- **New Features** for `semver:minor`;
- **Fixes** for `semver:patch`;
- **Other Changes** as a catch-all.

Generated notes span the previous stable tag through the new tag. As a result,
ordinary unlabeled pull requests merged since the last release are included in
the next release's **Other Changes** section. Existing release descriptions are
left unchanged, including any historical links.

## Deterministic Scripts and Tests

Release policy is kept out of opaque inline workflow expressions:

- `scripts/validate-release-labels.sh` validates a newline-delimited label set
  and returns the selected bump or an empty value;
- `scripts/release-labels-at-merge.sh` replays normalized `labeled`,
  `unlabeled`, and `merged` timeline events and returns the labels active at
  merge;
- `scripts/latest-stable-version.sh` selects the numeric maximum from strict
  unprefixed stable tags;
- `scripts/next-semver.sh` accepts one strict stable version and one supported
  bump, then prints the next strict stable version;
- `scripts/plan-release.sh` consumes normalized pull request, tag, release, and
  Git ancestry state and returns `noop`, `wait`, `resume`, or `create` with the
  exact previous version, candidate version, and blocking pull request when
  applicable;
- `scripts/release-context-for-sha.sh` is the read-only GitHub adapter that
  paginates commit association and issue timeline data, then invokes the pure
  label policy for the exact merge SHA;
- `scripts/publish-release.sh` is the trusted GitHub adapter: it paginates and
  normalizes API state, polls the pure planner, refreshes state immediately
  before mutation, creates an exact lightweight tag ref, generates notes, and
  publishes the immutable Release;
- `scripts/test-release-contract.sh` exercises the release-label and version
  matrices without network access or GitHub state.
- `scripts/test-publish-release.sh` executes the trusted publisher against
  disposable local Git repositories and fake GitHub/sleep adapters.

Unrelated labels are ignored defensively, but any label beginning with
`semver:` that is not one of the three supported values fails validation. The
tests cover zero, one, duplicate, unrelated, unsupported SemVer, and
conflicting labels;
label addition and removal before and after the merge boundary; major, minor,
and patch transitions; malformed versions; unsupported bump values; and the
current `0.2.0` transition examples. Tag-discovery tests prove that arbitrary
tags, `v`-prefixed versions, and prereleases are ignored, while absence of any
strict stable baseline fails. Fixture-driven state tests cover predecessor
selection, completed old reruns, partial-tag recovery, stale-ref refresh,
conflicting tag ownership, and rapid releases with different bump types.
Disposable local-Git publisher tests replace `gh` and `sleep` to cover no-op,
create, resume, bounded wait, stale-state refresh, HTTP 422 ref races, non-422
failures, partial Release retry, invalid ancestry metadata, and annotated-tag
rejection without contacting GitHub.
Pure policy scripts use POSIX shell-compatible constructs and add no dependency
to the Swift package or its runtime products. The ancestry-aware planner
requires a full-history Git checkout and runner-provided `git`. GitHub adapters
additionally require runner-provided `gh` and `jq`; CI presentation requires
runner-provided `xcbeautify`. Workflows assert tool presence and record versions
so runner-image drift is visible.

## Failure, Retry, and Ordering

Different merge commits do not share a GitHub Actions concurrency group.
GitHub's default concurrency queue retains only one pending job, while even its
extended queue does not guarantee that jobs enter in main-branch order. Using
one repository-wide group could therefore drop or reorder a qualifying merge.

Instead, every labeled merge keeps its own release job, keyed by
`merge_commit_sha`. Main-branch ancestry is the ordering source: a job cannot
publish until every earlier qualifying ancestor has a consistent GitHub
Release. Concurrent later jobs wait without blocking the earlier job from
running. A per-commit concurrency group may deduplicate retries for the same
SHA because those runs represent one logical release; different SHAs never
share that group. Duplicate execution remains safe because tag creation is
validated and atomic at the remote ref boundary.

The workflow fails closed:

- documentation, compilation, or test failure prevents release execution;
- conflicting labels, an ambiguous pull request association, no valid stable
  baseline, a non-ancestor baseline, an unreleased qualifying ancestor after
  the bounded wait, or a retry tag inconsistent with the approved bump stops
  publication;
- tags are never overwritten or force-pushed;
- published releases are never edited or deleted automatically.

Tag creation and GitHub Release creation are separate GitHub operations and
cannot be atomic. If tag creation succeeds but release publication fails, a
rerun detects the stable tag already pointing to the triggering CI head SHA,
proves that it is exactly the expected bump from the preceding version, and
creates the missing release instead of incrementing again. If both already
exist consistently, any later rerun succeeds without duplicating or changing
them, even after newer releases have been published. A mismatched existing tag
or release requires manual investigation.

## Security and Permissions

The CI workflow declares `contents: read` by default and never contains a
write-capable job. This prevents a same-repository pull request from modifying
a job condition and obtaining a write token before review.

The separate publication workflow exists on the default branch and receives
`contents: write` only after a successful CI `workflow_run` for a trusted push
to `main`. It rechecks the triggering repository, event, branch, conclusion,
and head SHA before checkout. It does not download triggering-workflow
artifacts, restore its caches, use `pull_request_target`, or check out untrusted
pull request code. Read-only issue and pull request permissions are added only
where timeline reconstruction requires them.

Third-party actions are avoided; the official checkout action is pinned to an
immutable commit SHA in both workflows.

The automatically supplied `GITHUB_TOKEN` publishes tags and releases. No
personal access token or long-lived release credential is introduced.

## Documentation Contract

`docs/RELEASING.md` becomes the canonical maintainer and AI-agent release
contract. It documents label meanings, the zero/one/multiple-label rule,
version calculation, generated notes, automatic publication, permissions,
failure recovery, and the stable-only policy.

`CONTRIBUTING.md` links to the release guide, names `release-label` and
`build-and-test` as required checks, explains that selecting one SemVer label
authorizes publication after merge, and retains Conventional Commits as a local
rule. `AGENTS.md` routes release work to the guide, and `docs/README.md` lists
the guide in the documentation map.

`scripts/validate-documentation.sh` will require the new guide, both workflow
files, release configuration, and release scripts; verify the stable label
names, required checks, read-only CI boundary, and trusted publication trigger;
and reject references that present Gitlint as a GitHub merge gate. It will also
reject the three obsolete workflow files after migration.

## Repository Enforcement

After the new workflow has run successfully on the pull request, the active
default-branch ruleset will require these two status contexts:

- `release-label`;
- `build-and-test`.

The ruleset update must re-read the live configuration and preserve every
existing condition and rule, including deletion protection, non-fast-forward
protection, and pull request review requirements. It changes only the required
status-check rule. The obsolete Build, Test, and Gitlint contexts will not be
required.

The pull request remains Draft until the repository changes, local checks, and
new GitHub checks have been reviewed. Its description will disclose the
automatic publication behavior and the fact that the release path itself runs
only after a future qualifying merge.

## Verification and Confidence Boundary

Implementation verification consists of:

```sh
sh scripts/test-release-contract.sh
sh scripts/validate-documentation.sh
swift build --build-tests
swift test --skip-build
git diff --check
```

The workflow syntax will also be checked with `actionlint`, and the pull request
must show successful `release-label` and `build-and-test` GitHub checks before
the ruleset is updated.

Local script tests establish deterministic label and version behavior. The
pull request run establishes documentation, compilation, test, and label-gate
behavior without write permissions. It cannot safely prove production release
publication because the `release` job is intentionally skipped before merge.
The first merged pull request carrying exactly one `semver:*` label is therefore
the first end-to-end verification of tag and GitHub Release publication.

## Scope

This change owns read-only CI workflow consolidation, a separate privileged
publication workflow, readable SwiftPM output, compiled test reuse, SemVer
label validation, stable tag and GitHub Release publication, release
documentation, release-contract tests, repository labels, and required status
checks.

It does not change Swift source, public API, deployment targets,
`swift-tools-version`, package dependencies, historical tags or releases,
pre-release policy, merge methods, reviewer requirements, or unrelated
repository settings.
