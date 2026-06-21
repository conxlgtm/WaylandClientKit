# WaylandGraphicsPreview

Use renderer-neutral preview APIs to request software or managed GPU
presentation for a Wayland window and inspect typed runtime-path facts.
Package-scoped external-buffer helpers provide preview evidence for
renderer-owned dmabuf presentation without exposing raw graphics handles as
public API.

`WaylandGraphicsPreview` is source-breaking preview API. Public drift is still
baseline and audit tracked, but framework authors should expect source changes
while managed GPU behavior is proven across compositors.

Raw protocol and raw GPU objects stay internal. Runtime results report active,
fallback, failed, unavailable, advertised, and configured states through public
value types.

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

### Backing And Frames

- ``WaylandGraphicsWindowBacking``
- ``WaylandGraphicsFrameLease``
- ``WaylandGraphicsFrameContract``
- ``WaylandGraphicsSubmittedFrame``
- ``WaylandGraphicsClearFrame``
- ``WaylandGraphicsFrameResult``
- ``WaylandGraphicsExternalBufferConfiguration``
- ``WaylandGraphicsSurfaceGeneration``
- ``WaylandGraphicsExternalConfigurationID``
- ``WaylandGraphicsDRMFormat``
- ``WaylandGraphicsDRMFormatModifier``
- ``WaylandGraphicsExternalSynchronizationAvailability``
- ``WaylandGraphicsExternalAlphaMode``
- ``WaylandGraphicsXRGBColor``
- ``WaylandGraphicsFrameMetadata``
- ``WaylandGraphicsDamageRegion``
- ``WaylandGraphicsAlphaModifier``
- ``WaylandGraphicsColorRepresentation``
- ``WaylandGraphicsColorAlphaMode``

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
