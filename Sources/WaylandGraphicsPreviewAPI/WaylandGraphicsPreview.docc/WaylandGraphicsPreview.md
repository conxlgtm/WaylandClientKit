# WaylandGraphicsPreview

Use renderer-neutral preview APIs to request software or managed GPU backing
for a Wayland window and inspect typed runtime-path facts.

`WaylandGraphicsPreview` is preview and source-breaking. It is not the stable
foundation API. Public drift is still baseline and audit tracked, but framework
authors should expect source changes while managed GPU behavior is proven across
compositors.

The preview product does not expose raw Wayland, GBM, EGL, DRM, dmabuf,
syncobj, renderer, swapchain, scene graph, widget, or layout handles; raw GPU
handles stay internal. External-buffer planes consume owned Linux file
descriptors during construction, but the descriptor is not exposed as public
stored state after transfer. Runtime results report active, fallback, failed,
unavailable, advertised, and configured states through public value types.

## Topics

### Start Here

- <doc:GraphicsPreviewOverview>
- <doc:ManagedGraphicsBacking>
- <doc:FrameLeases>
- <doc:ExternalBufferSubmission>
- <doc:SchedulingAndColorMetadata>

### Runtime Truth

- <doc:GraphicsRuntimePath>
- <doc:SoftwareFallback>
- <doc:ManagedGPUPreview>

### Configuration

- ``WaylandGraphicsConfiguration``
- ``WaylandGraphicsBackingKind``
- ``WaylandGraphicsFallbackPolicy``
- ``WaylandGraphicsSynchronizationPolicy``
- ``WaylandGraphicsPacingPolicy``
- ``WaylandGraphicsMetadataPolicy``
- ``WaylandGraphicsPresentationFeedbackPolicy``
- ``WaylandGraphicsFrameSchedule``
- ``WaylandGraphicsFramePacingRequest``
- ``WaylandGraphicsCommitTimingRequest``
- ``WaylandGraphicsPresentationTarget``

### Backing And Frames

- ``WaylandGraphicsWindowBacking``
- ``WaylandGraphicsFrameLease``
- ``WaylandGraphicsSubmittedFrame``
- ``WaylandGraphicsClearFrame``
- ``WaylandGraphicsFrameResult``
- ``WaylandGraphicsXRGBColor``
- ``WaylandGraphicsFrameMetadata``
- ``WaylandGraphicsDamageRegion``
- ``WaylandGraphicsAlphaModifier``
- ``WaylandGraphicsColorRepresentation``
- ``WaylandGraphicsColorAlphaMode``

### External Buffers

- ``WaylandGraphicsDRMFormat``
- ``WaylandGraphicsDRMFormatModifier``
- ``WaylandGraphicsExternalBufferDescriptor``
- ``WaylandGraphicsExternalBufferPlane``
- ``WaylandGraphicsExternalBufferPlanes``
- ``WaylandGraphicsExternalSynchronization``
- ``WaylandGraphicsExternalAcquireSync``

### Runtime Path Values

- ``WaylandGraphicsRuntimePath``
- ``WaylandGraphicsRuntimeStatus``
- ``WaylandGraphicsSurfaceCapabilities``
- ``WaylandGraphicsProtocolAvailability``
- ``WaylandGraphicsFramePacingAvailability``
- ``WaylandGraphicsColorMetadataAvailability``
- ``WaylandGraphicsPacingStatus``
- ``WaylandGraphicsMetadataStatus``
- ``WaylandGraphicsFallbackReason``
- ``WaylandGraphicsUnavailableReason``
- ``WaylandGraphicsBackingDecision``

### Errors

- ``WaylandGraphicsError``
- ``WaylandGraphicsSubmissionFailure``
- ``WaylandGraphicsSubmissionStage``
- ``WaylandGraphicsSubmissionOperation``
