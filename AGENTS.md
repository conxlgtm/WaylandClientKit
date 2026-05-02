# Repository Workflow

## Pull Requests

When creating or updating a pull request:

- Do not mention tools, automation, or generated-by text.
- Use factual, concise prose.
- Describe what changed and why it changed.
- Include validation only when checks were actually run.
- Do not add embellishment, marketing language, or co-author trailers unless explicitly requested.
- Open pull requests ready for review by default; use draft only when explicitly requested.

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
