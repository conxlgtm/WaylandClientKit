# Public Readiness

Status reflects this branch and the repository settings checked during the
public-readiness pass.

## Legal

| Status | Item | Notes |
| --- | --- | --- |
| PASS | Root `LICENSE` exists | Apache License 2.0. |
| PASS | README links the license | See README License section. |
| PASS | Compatibility policy references the license | License grants reuse rights. Policy defines API stability. |
| PASS | Vendored protocol XML untouched | No protocol XML changed in this pass. |
| PASS | Generated protocol artifacts untouched | No generated protocol artifacts changed in this pass. |

## Security

| Status | Item | Notes |
| --- | --- | --- |
| PASS | `SECURITY.md` exists | Private reporting instructions and scope are documented. |
| FAIL | Private vulnerability reporting enabled | GitHub REST endpoint returned `404` while the repo is private. Re-check after visibility/plan changes. |
| PASS | Dependabot alerts enabled | Enabled through `PUT /repos/{owner}/{repo}/vulnerability-alerts`. |
| PASS | Dependency graph enabled | GitHub wires this to vulnerability alerts through the same endpoint. |
| PASS | Dependabot security updates enabled | Enabled through `PUT /repos/{owner}/{repo}/automated-security-fixes`. |
| FAIL | Secret scanning enabled | Needs repository security settings access after public/plan availability is confirmed. |

## Community Files

| Status | Item | Notes |
| --- | --- | --- |
| PASS | `CODE_OF_CONDUCT.md` exists | Contributor Covenant with real maintainer contact. |
| PASS | `SUPPORT.md` exists | Questions, bugs, security, protocol requests, and compositor evidence routes. |
| PASS | Issue templates exist | Bug, feature, protocol support, and compositor evidence forms. |
| PASS | PR template exists | Public API, protocol, docs, safety, examples, and validation prompts. |
| PASS | CODEOWNERS is current | Protocols, generated C, shims, wrappers, docs, workflows, safety, examples, tests, and tooling are owned. |

## Repository Settings

| Status | Item | Notes |
| --- | --- | --- |
| PASS | Issues enabled | On. |
| PASS | Wiki disabled | Off. |
| PASS | Projects disabled | Off after settings update. |
| PASS | Merge commits disabled | Squash and rebase remain allowed. |
| PASS | Delete head branches enabled | On after settings update. |
| FAIL | Main branch protection exists | GitHub returned `403`: upgrade or make repository public. |
| FAIL | CODEOWNERS review required | Depends on branch protection/ruleset availability. |
| FAIL | Required status check `check / check` configured | Depends on branch protection/ruleset availability. |
| FAIL | Force pushes and deletions blocked | Depends on branch protection/ruleset availability. |

## CI And Branch Protection

| Status | Item | Notes |
| --- | --- | --- |
| PASS | Cheap PR check exists | `.github/workflows/check.yml` job `check`. |
| PASS | Full checks remain manual/scheduled | Generated freshness, release, sanitizer, and smoke jobs are full/manual/scheduled. |
| PASS | CI job names are unique | Current workflow job keys are unique. |
| PASS | Public docs refer to `wck` | Stale old command names are audited separately. |

## README And Docs

| Status | Item | Notes |
| --- | --- | --- |
| PASS | README is short and public-facing | Long support and dependency tables moved to docs. |
| PASS | Support matrix exists | See `docs/support-matrix.md`. |
| PASS | Linux dependencies doc exists | See `docs/linux-dependencies.md`. |
| PASS | Versioning policy exists | See `docs/versioning.md`. |
| PASS | Public readiness checklist exists | This file. |
| PASS | README marks preview graphics API | `WaylandGraphicsPreview` is called source-breaking preview API. |
| PASS | README states the scope boundary | Explicitly stated in the opening section. |

## Release And Versioning

| Status | Item | Notes |
| --- | --- | --- |
| PASS | First public tag plan documented | `0.1.0` after readiness checks pass. |
| PASS | `0.x` breakage policy documented | Source-breaking changes allowed with audit/baseline updates. |
| PASS | Preview API policy documented | `WaylandGraphicsPreview` remains source-breaking preview. |

## Package Metadata

| Status | Item | Notes |
| --- | --- | --- |
| PASS | Repository description prepared | `Swift-native Wayland client substrate for Linux: windows, input, data transfer, text input, protocol facts, and preview graphics APIs.` |
| PASS | Homepage intentionally blank | Leave blank until DocC or GitHub Pages is published. |
| PASS | Topics selected | See below. |

## Recommended GitHub Topics

Use:

- `swift`
- `wayland`
- `linux`
- `swift-package`
- `swiftpm`
- `gui`
- `desktop`
- `client`
- `wayland-client`
- `xkbcommon`
- `dmabuf`
- `egl`
- `gbm`
- `linux-desktop`
- `graphics`
- `windowing`
- `clipboard`
- `text-input`
- `input-method`

Avoid for now:

- `swiftui`
- `swift-ui`
- `ui-framework`
- `toolkit`

## Known Caveats

| Status | Item | Notes |
| --- | --- | --- |
| FAIL | Repository is public | Still private during this branch pass. |
| FAIL | Branch protection is enabled | Blocked until public/plan support is available. |
| PASS | Required pre-public command pass is complete | Required commands passed on this branch. |
| FAIL | Foundation readiness check passes | `swift run wck ci foundation-check` fails because live compositor evidence is incomplete. This is a pre-foundation caveat, not hidden. |

## Before Flipping Visibility

| Status | Item | Notes |
| --- | --- | --- |
| PASS | Legal/community files exist | License, security, conduct, support, and templates are present. |
| PASS | README/docs portal is public-facing | README is short and links to focused docs. |
| PASS | Secret/path audit has been reviewed | False positives documented below. |
| FAIL | Branch protection/ruleset is ready | Currently unavailable while private. |
| PASS | Security settings are enabled or documented unavailable | Dependabot/dependency graph enabled. Private vulnerability reporting and secret scanning are unavailable in the current private repo state. |
| PASS | Final required command pass succeeds | Optional foundation-check fails on incomplete live compositor evidence. |

## After Flipping Visibility

| Status | Item | Notes |
| --- | --- | --- |
| FAIL | Re-run branch protection setup | Required after GitHub enables the feature. |
| FAIL | Re-run security settings setup | Required after GitHub enables the feature. |
| FAIL | Confirm community profile checklist | Check GitHub community profile UI. |
| FAIL | Create first public tag | Use `0.1.0` after checks pass. |

## Secret And Stale-Name Audit Notes

The pre-public grep command was reviewed:

```bash
git grep -nE "(token|secret|password|PRIVATE|/home/|/Users/|TODO public|FIXME public|ssh-rsa|BEGIN .*PRIVATE KEY)"
```

False-positive categories:

- `token`: xdg activation/reposition protocol tokens, test token strings, and
  unsafe-token allowlist naming.
- `PRIVATE`: generated Wayland `WL_PRIVATE` visibility macro and upstream XML
  `MAP_PRIVATE` wording.
- `password`: text-input content-purpose enum names from upstream protocol
  XML/baselines.
- `/home/`: test fixture paths such as `/home/example`, not real machine logs.

No `ssh-rsa`, `BEGIN ... PRIVATE KEY`, `/Users/`, `TODO public`, or
`FIXME public` hits were found.

The stale-name sweep was reviewed:

```bash
git grep -n -i "<old project and command names>"
```

The only hit was a stale `.swiftlint.yml` comment, updated to `wck`.
