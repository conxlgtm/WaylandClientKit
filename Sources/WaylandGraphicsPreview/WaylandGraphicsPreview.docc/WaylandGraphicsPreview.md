# WaylandGraphicsPreview

Use renderer-neutral preview APIs to request software, managed GPU, or
renderer-owned external-buffer presentation for a Wayland window and inspect
typed runtime-path facts.

`WaylandGraphicsPreview` is source-breaking preview API. Public drift is still
baseline and audit tracked, but framework authors should expect source changes
while managed GPU behavior is proven across compositors.

Raw protocol and raw GPU objects stay internal. Runtime results report active,
fallback, failed, unavailable, advertised, and configured states through public
value types.

## Topics

### Start Here

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
- ``WaylandGraphicsPresentationPolicy``
- ``WaylandGraphicsFallbackDisposition``
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
- ``WaylandGraphicsExternalBuffer``
- ``WaylandGraphicsExternalBufferID``
- ``WaylandGraphicsExternalBufferPlane``
- ``WaylandGraphicsExternalBufferPlanes``
- ``WaylandGraphicsExternalBufferDescriptor``
- ``WaylandGraphicsExternalBufferConfiguration``
- ``WaylandGraphicsExternalBufferRenderLease``
- ``WaylandGraphicsExternalBufferSubmissionReceipt``
- ``WaylandGraphicsExternalReleaseResult``
- ``WaylandGraphicsExternalReleaseMechanism``
- ``WaylandGraphicsExternalReleaseSynchronization``
- ``WaylandGraphicsExternalSyncobjTimelinePoint``
- ``WaylandGraphicsExternalPresentationFeedbackIdentity``
- ``WaylandGraphicsExternalPresentationFeedbackResult``
- ``WaylandGraphicsExternalRetirementReason``
- ``WaylandGraphicsExternalBufferLifecycle``
- ``WaylandGraphicsExternalSubmissionID``
- ``WaylandGraphicsExternalSyncTimeline``
- ``WaylandGraphicsExternalSyncTimelineID``
- ``WaylandGraphicsExternalSyncPoint``
- ``WaylandGraphicsExternalAcquireSynchronization``
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
- ``WaylandGraphicsReason``
- ``WaylandGraphicsBackingDecision``

### Errors

- ``WaylandGraphicsError``
- ``WaylandGraphicsSubmissionFailure``
- ``WaylandGraphicsSubmissionStage``
- ``WaylandGraphicsSubmissionOperation``
