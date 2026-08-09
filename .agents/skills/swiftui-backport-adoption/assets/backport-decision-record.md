# Backport Decision Record: [API or feature]

## Client Readiness

| Input | Status (`Discovered`, `Confirmed`, or `Missing`) | Evidence or gap |
| --- | --- | --- |
| Repository and owning module | | |
| Deployment targets and supported platforms | | |
| Native declaration and availability | | |
| Required behavior and native/fallback deltas | | |
| Affected call sites and helpers | | |
| Verification commands and supported runtimes | | |
| Named owner | | |
| Decision-record convention | | |
| Planned removal release | | |

## Context

- Status: Proposed | Accepted | Blocked | Retired
- Native API and signature:
- Native availability by platform:
- Consumer minimum targets:
- Supported platforms:
- Affected modules and call sites:
- Decision date:
- Linked decisions and record paths:

## Category

- Selected: `redirect-fallback` | `compatibility-type` | `behavioral-polyfill` | `no-op-fallback`
- `redirect-fallback` rejected or selected because:
- `compatibility-type` rejected or selected because:
- `behavioral-polyfill` rejected or selected because:
- `no-op-fallback` rejected or selected because:

## Behavior Contract

- Unified call site:
- Native behavior:
- Fallback behavior:
- Parameter mapping:
- Semantic and user-visible deltas:
- Unsupported combinations:

## Risk

| Dimension | Impact | Evidence or mitigation |
| --- | --- | --- |
| Correctness | None / Low / Medium / High | |
| Accessibility | None / Low / Medium / High | |
| Security | None / Low / Medium / High | |
| Data integrity | None / Low / Medium / High | |
| Interaction and layout | None / Low / Medium / High | |

## Platform Matrix

| Platform and OS | Expected branch | Executed evidence | Gaps or proxy |
| --- | --- | --- | --- |
| | Native / Fallback / Both | | |

## Lifecycle

### Retained-Type Exception

Complete these fields only when a `Backported` type remains unannotated. Otherwise write `None; the annotation default applies`.

- Retained unannotated `Backported` type:
- Independent product value:
- Evidence supporting the independent product value:
- Reason the type itself remains unannotated:
- Compatibility-only modifiers, native conversions, bridges, compatibility initializers, and similar surfaces to deprecate:
- Owner responsible for the retained value and exception:
- Independent retained-type review/removal trigger:

| Declaration or surface | Lifecycle role (`retained unannotated type` or `compatibility-only surface`) | Platform | Native since | Deprecated | Obsoleted or omitted | Replacement and message | Evidence, no-replacement reason, or exception |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |

## Verification

- Ordinary compatibility-layer and unified-call-site type-checking for every supported platform:
- Ordinary retained-type construction, storage, and product use at and above native availability without a type-level deprecation diagnostic, if the exception applies:
- Lifecycle threshold coverage below and at `deprecated`, and at `obsoleted` when present, for every annotated compatibility-only surface:
- Supported platforms or surfaces without verified lifecycle annotations, with no-replacement or lifecycle-exception reasons:
- Compiler diagnostics:
- Fallback behavior tests:
- Native behavior tests:
- Unified call-site coverage:
- UI, snapshot, accessibility, or device validation:
- Commands and results:
- Remaining confidence limits:

## Ownership and Removal

- Owner:
- Native-availability removal trigger:
- Planned removal release:
- Actual removal release:
- Closed date:
- Compatibility-only surface removal trigger and evidence:
- Retained-type review/removal status and evidence, if the exception applies:
- Removal status and evidence:
