# Public identity visibility

This file is generated from `docs/identity-categories.json` and public Swift declarations. It records which identities callers may construct and which stored values are public.

Run `swift run wck identity verify --update` after reviewing an intentional identity contract change.

| Type | Category | Constructor | Stored value | Value visibility | Source |
| --- | --- | --- | --- | --- | --- |
| `ActivationAppID` | application identity | `public` | `value` | `public` | `Sources/WaylandClient/Public/Activation/ActivationDomainTypes.swift` |
| `ActivationToken` | opaque protocol token | `public` | `value` | `public` | `Sources/WaylandClient/Public/Activation/ActivationDomainTypes.swift` |
| `ClipboardOfferIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DataTransfer/DataTransferDomainTypes.swift` |
| `ClipboardSourceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DataTransfer/DataTransferDomainTypes.swift` |
| `DiagnosticID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Display/DisplayEvent.swift` |
| `DragOfferIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DataTransfer/DragAndDropDomainTypes.swift` |
| `DragSourceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DataTransfer/DragSource.swift` |
| `ForeignToplevelID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DesktopIntegration/DesktopIntegrationDomainTypes.swift` |
| `IdleInhibitorID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DesktopIntegration/DesktopIntegrationDomainTypes.swift` |
| `InputSerial` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Input/InputIdentity.swift` |
| `KeyboardShortcutsInhibitorID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DesktopIntegration/DesktopIntegrationDomainTypes.swift` |
| `OutputID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Display/Output.swift` |
| `OutputManagementHeadID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Display/Output.swift` |
| `OutputManagementModeID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Display/Output.swift` |
| `PointerConstraintID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Input/InputEvent.swift` |
| `PointerGestureSubscriptionID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Input/PointerCaptureDomainTypes.swift` |
| `PopupSurfaceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Input/InputIdentity.swift` |
| `PrimarySelectionOfferIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DataTransfer/DataTransferDomainTypes.swift` |
| `PrimarySelectionSourceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DataTransfer/DataTransferDomainTypes.swift` |
| `RelativePointerSubscriptionID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Input/PointerCaptureDomainTypes.swift` |
| `SeatID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Input/InputIdentity.swift` |
| `SoftwareFrameBufferID` | client identity | `internal` | `rawValue` | `private` | `Sources/WaylandClient/Public/Rendering/SoftwareFrame.swift` |
| `SubsurfaceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Subsurface/SubsurfaceDomainTypes.swift` |
| `SurfacePresentationIdentity` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Presentation/PresentationFeedback.swift` |
| `TabletID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Input/TabletInputDomainTypes.swift` |
| `TabletPadID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Input/TabletInputDomainTypes.swift` |
| `TabletToolID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Input/TabletInputDomainTypes.swift` |
| `ToplevelDragID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DataTransfer/DragSource.swift` |
| `TouchID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Input/TouchID.swift` |
| `WaylandGraphicsExternalBufferID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandGraphicsPreview/Public/WaylandGraphicsSubmission.swift` |
| `WaylandGraphicsExternalConfigurationID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandGraphicsPreview/Public/WaylandGraphicsSubmission.swift` |
| `WaylandGraphicsExternalPresentationFeedbackIdentity` | public projection | `package` | `submissionID` | `public` | `Sources/WaylandGraphicsPreview/Public/WaylandGraphicsSubmission.swift` |
| `WaylandGraphicsExternalSubmissionID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandGraphicsPreview/Public/WaylandGraphicsSubmission.swift` |
| `WaylandGraphicsExternalSyncTimelineID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandGraphicsPreview/Public/WaylandGraphicsSubmission.swift` |
| `WaylandProtocolObjectID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Errors/DisplayError.swift` |
| `WindowDialogID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/DesktopIntegration/DesktopIntegrationDomainTypes.swift` |
| `WindowID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Input/InputIdentity.swift` |
