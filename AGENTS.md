# Repository Workflow

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
- Reject public raw Wayland, GBM, EGL, DRM, dmabuf, syncobj, file descriptor,
  or unsafe implementation handles.
- Check that user-facing docs explain new public behavior before release notes
  or status docs claim it.
