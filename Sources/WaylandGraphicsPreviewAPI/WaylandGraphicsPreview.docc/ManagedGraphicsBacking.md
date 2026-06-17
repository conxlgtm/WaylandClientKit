# Managed Graphics Backing

``WaylandGraphicsWindowBacking`` is the public handle for a managed
graphics-capable window. It hides whether the current frame path is software,
managed GPU, fallback, or failed.

## Creating A Backing

Create a normal `WaylandClient.Window`, then create a graphics backing through
the public preview API on the display. The backing owns submission state and
closes the underlying managed window when ``WaylandGraphicsWindowBacking/close()``
is called.

```swift
let configuration = WaylandGraphicsConfiguration(
    backingPreference: .managedGPU,
    presentationFeedbackPolicy: .requestWhenAvailable
)
let backing = try await display.createGraphicsWindowBacking(
    configuration: configuration
)
```

## What The Backing Owns

WaylandClientKit owns the frame lease state, software frame presentation, internal
managed GPU setup, presentation-feedback request plumbing, and runtime-path
updates. Callers choose whether fallback is acceptable for a given frame path.

## Errors

Expect `WaylandGraphicsError.windowClosed`, `WaylandGraphicsError.backingClosed`,
`WaylandGraphicsError.frameLeaseActive`, `WaylandGraphicsError.frameLeaseConsumed`,
unavailable reasons, fallback requirements, invalid damage, unsupported metadata,
unsupported pacing, and typed submission failures.
