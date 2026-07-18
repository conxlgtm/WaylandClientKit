# Public identity visibility

This file is generated from `docs/identity-categories.json` and public Swift declarations. It records which identities callers may construct and which stored values are public.

Run `swift run wck identity verify --update` after reviewing an intentional identity contract change.

| Type | Category | Constructor | Stored value | Value visibility | Source |
| --- | --- | --- | --- | --- | --- |
| `ActivationAppID` | application identity | `public` | `value` | `public` | `Sources/WaylandClient/Public/Activation/ActivationDomainTypes.swift` |
| `ActivationToken` | opaque protocol token | `public` | `value` | `public` | `Sources/WaylandClient/Public/Activation/ActivationDomainTypes.swift` |
| `ClipboardOfferIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `ClipboardSourceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `DiagnosticID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `DragOfferIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `DragSourceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `ForeignToplevelID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `IdleInhibitorID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `InputSerial` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `KeyboardShortcutsInhibitorID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `OutputID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `OutputManagementHeadID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `OutputManagementModeID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `PointerConstraintID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Input/InputEvent.swift` |
| `PointerGestureSubscriptionID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `PopupSurfaceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `PrimarySelectionOfferIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `PrimarySelectionSourceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `RelativePointerSubscriptionID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `SeatID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `SoftwareFrameBufferID` | client identity | `internal` | `rawValue` | `private` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `SubsurfaceIdentity` | public projection | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `SurfacePresentationIdentity` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `TabletID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `TabletPadID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `TabletToolID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `ToplevelDragID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `TouchID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `WaylandGraphicsExternalBufferID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandGraphicsPreview/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `WaylandGraphicsExternalConfigurationID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandGraphicsPreview/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `WaylandGraphicsExternalPresentationFeedbackIdentity` | public projection | `package` | `submissionID` | `public` | `Sources/WaylandGraphicsPreview/Public/WaylandGraphicsSubmission.swift` |
| `WaylandGraphicsExternalSubmissionID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandGraphicsPreview/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `WaylandGraphicsExternalSyncTimelineID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandGraphicsPreview/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `WaylandProtocolObjectID` | raw protocol identity | `public` | `rawValue` | `public` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `WindowDialogID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
| `WindowID` | client identity | `package` | `rawValue` | `package` | `Sources/WaylandClient/Public/Generated/GeneratedPublicIdentityDeclarations.swift` |
