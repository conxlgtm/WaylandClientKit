# Advanced Graphics Boundary

The current experimental baseline uses `wl_shm` and `SoftwareFrame`.

SHM software rendering is the baseline path. It uses core Wayland objects before the project adds GPU synchronization, dmabuf import/export rules, or EGL platform details.

## Current Rendering Path

Current public rendering API:

```swift
try window.redraw { frame in
    frame.withXRGB8888Rows { row, pixels in
        // Write XRGB8888 pixels.
    }
}
```

The high-level actor API keeps the same synchronous borrowed-frame drawing rule:

```swift
try await display.redraw(windowID) { frame in
    frame.withXRGB8888Rows { row, pixels in
        // Write XRGB8888 pixels.
    }
}
```

This API is explicitly software-backed. `SoftwareFrame` is a noncopyable borrowed value:
the drawing callback can write rows during the callback, but cannot retain the frame for
later mutation after the buffer has been committed or recycled. Keep the `SoftwareFrame`
name.

Do not rename it into a generic renderer before a second rendering implementation exists.

## Preview Target Shape

The graphics preview product is additive:

```text
WaylandGraphicsPreview
    public preview facade
    depends on WaylandClient
    reports renderer-neutral capability, runtime-path, and fallback facts
    does not expose raw Wayland/EGL/GBM/DRM handles

WaylandGraphicsCore
    package-internal target
    depends on WaylandRaw plus GBM, DRM, EGL, and GLES system-library targets
    owns GBM/EGL/dmabuf adapters while they are still under development
```

Current graphics system-library targets:

- `CEGLSystem`
- `CGLESv2System`
- `CGBMSystem`
- `CDRMSystem`

Current graphics protocol XML:

- linux-dmabuf,
- presentation-time,
- viewporter,
- fractional-scale.

`WaylandGPUPreview` bridges the graphics core target to package-internal
managed-window presentation. It is not a public `WaylandClient` renderer API.

The public preview boundary is documented in
[Graphics Preview API](graphics-preview-api.md).

## API Risks

Do not introduce these without a concrete second implementation:

- generic `Renderer`,
- generic `Swapchain`,
- generic `Drawable`,
- generic `PresentationEngine`.

Those names would commit the API before the requirements are known.

Add public GPU APIs beside the software path only after the required ownership
and synchronization rules are known.

## Lifecycle Risks

Advanced graphics work must still preserve Wayland invariants:

- buffers must not be reused before compositor release,
- configure/ack ordering still matters,
- frame callbacks still pace redraw,
- surface commits remain ordered,
- protocol errors must be surfaced clearly.

## Baseline Rule

No GPU feature is required for the current experimental baseline.

The current output is this design boundary, a public preview capability/fallback
API, and a package-internal EGL/GBM/dmabuf probe. It is not a public rendering
API.
