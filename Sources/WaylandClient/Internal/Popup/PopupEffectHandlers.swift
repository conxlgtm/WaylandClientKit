package struct PopupEffectHandlers {
    package var ackConfigure: (UInt32) throws -> Void
    package var publishDismissed: (PopupLifecycleEvent) -> Void
    package var publishClosed: (PopupLifecycleEvent) -> Void
    package var publishRedrawRequested: (PopupLifecycleEvent) -> Void
    package var cancelFrameCallback: () -> Void
    package var retireSwapchain: () -> Void
    package var destroyRoleObjects: () throws -> Void

    package init(
        ackConfigure configureAcknowledgement: @escaping (UInt32) throws -> Void,
        publishDismissed dismissedPublication: @escaping (PopupLifecycleEvent) -> Void,
        publishClosed closedPublication: @escaping (PopupLifecycleEvent) -> Void,
        publishRedrawRequested redrawPublication: @escaping (PopupLifecycleEvent) -> Void,
        cancelFrameCallback frameCancellation: @escaping () -> Void,
        retireSwapchain swapchainRetirement: @escaping () -> Void,
        destroyRoleObjects roleObjectDestruction: @escaping () throws -> Void
    ) {
        ackConfigure = configureAcknowledgement
        publishDismissed = dismissedPublication
        publishClosed = closedPublication
        publishRedrawRequested = redrawPublication
        cancelFrameCallback = frameCancellation
        retireSwapchain = swapchainRetirement
        destroyRoleObjects = roleObjectDestruction
    }
}

package func interpretPopupEffects(
    _ effects: [PopupEffect],
    parentWindowID: WindowID,
    handlers: PopupEffectHandlers
) throws {
    for effect in effects {
        switch effect {
        case .ackConfigure(let serial):
            try handlers.ackConfigure(serial)
        case .publishDismissed(let event):
            handlers.publishDismissed(event)
        case .publishClosed(let event):
            handlers.publishClosed(event)
        case .publishRedrawRequested(let event):
            handlers.publishRedrawRequested(event)
        case .cancelFrameCallback:
            handlers.cancelFrameCallback()
        case .performSoftwarePresent:
            throw ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(
                    .invalidTransition(
                        from: "effect interpreter without draw closure",
                        event: "performSoftwarePresent"
                    )
                )
            )
        case .retireSwapchain:
            handlers.retireSwapchain()
        case .destroyRoleObjects:
            try handlers.destroyRoleObjects()
        }
    }
}
