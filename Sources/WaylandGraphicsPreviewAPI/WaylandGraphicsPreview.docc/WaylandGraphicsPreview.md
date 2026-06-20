# WaylandGraphicsPreview

Use renderer-neutral preview APIs to request software, managed GPU, or
renderer-owned external-buffer presentation for a Wayland window and inspect
typed runtime-path facts.

`WaylandGraphicsPreview` is source-breaking preview API. Public drift is still
baseline and audit tracked, but framework authors should expect source changes
while managed GPU behavior is proven across compositors.

Raw protocol and raw GPU objects stay internal. The external-buffer preview
boundary accepts move-only descriptors that consume `OwnedFileDescriptor`
instances without exposing raw Wayland, GBM, EGL, or pointer handles. Runtime
results report active, fallback, failed, unavailable, advertised, and configured
states through public value types.

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
- ``WaylandGraphicsExternalBufferSubmissionReceipt``
- ``WaylandGraphicsExternalBufferRenderLease``
- ``WaylandGraphicsExternalReleaseResult``
- ``WaylandGraphicsExternalBuffer``
- ``WaylandGraphicsExternalBufferDescriptor``
- ``WaylandGraphicsExternalBufferPlane``
- ``WaylandGraphicsExternalBufferConfiguration``
- ``WaylandGraphicsSurfaceGeneration``
- ``WaylandGraphicsExternalConfigurationID``
- ``WaylandGraphicsExternalBufferID``
- ``WaylandGraphicsExternalSubmissionID``
- ``WaylandGraphicsExternalSyncTimelineID``
- ``WaylandGraphicsDRMFormat``
- ``WaylandGraphicsDRMFormatModifier``
- ``WaylandGraphicsDRMModifier``
- ``WaylandGraphicsExternalSynchronizationAvailability``
- ``WaylandGraphicsBufferTransform``
- ``WaylandGraphicsExternalAlphaMode``
- ``WaylandGraphicsColorContract``
- ``WaylandGraphicsDamageCoordinateSpace``
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
