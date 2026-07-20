# Repository Workflow

## Project Language

Use ordinary project language in branch names, commits, pull requests,
documentation, comments, and status updates. Do not add tool, assistant, bot,
worker-role, or language-model references unless the subject specifically
requires one. Required filenames such as `AGENTS.md` are exempt.

## Pull Requests

When creating or updating a pull request:

- Do not mention tools, automation, or generated-by text.
- Use factual, concise prose.
- Describe what changed and why it changed.
- Include validation only when checks were actually run.
- Do not add embellishment, marketing language, or co-author trailers unless explicitly requested.
- Open pull requests ready for review by default. Use draft only when explicitly requested.

Use this default structure:

```md
## Summary

- Fact about what changed.
- Fact about what changed.

## Why

- Reason the change is needed.
- Reason the change is needed.

## Validation

- `command that was run`
```

For very small changes, combine Summary and Why into a short paragraph if that is clearer.

## Codex Reviews

When addressing Codex review feedback marked P1, P2, or P3:

- Fix the issue.
- Commit and push the fix.
- Request a fresh Codex review by commenting exactly:

  `@codex review`

- Do this before reporting the PR as updated or ready.
- If the review cannot be requested, state the reason explicitly.

## Public API And Foundation Reviews

When reviewing public API, documentation, managed GPU, or foundation readiness
work:

- Apply `docs/compatibility-policy.md` tiers.
- Require docs and public API audit/baseline updates for public API changes.
- Treat `WaylandGraphicsPreview` as preview, but still baseline/audit tracked.
- Reject active managed GPU claims without runtime-path evidence from a live
  compositor.
- Reject public raw Wayland proxies, GBM objects, EGL objects, borrowed integer
  file descriptors, raw pointers, or unsafe implementation handles.
- Permit narrow, audited, move-only graphics interop values in
  `WaylandGraphicsPreview` when they consume `OwnedFileDescriptor` ownership for
  renderer-owned dma-buf planes or synchronization timelines and do not expose
  borrowed descriptor integers or protocol objects.
- Check that user-facing docs explain new public behavior before release notes
  or status docs claim it.
