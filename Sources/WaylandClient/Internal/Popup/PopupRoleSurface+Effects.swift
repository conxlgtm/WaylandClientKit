extension PopupRoleSurface {
    package func interpretPopupEffects(_ effects: [PopupEffect]) throws {
        try WaylandClient.interpretPopupEffects(
            effects,
            parentWindowID: parentWindowID,
            handlers: popupEffectHandlers
        )
    }

    func interpretPopupEffects(
        _ effects: [PopupEffect],
        performSoftwarePresent: (PopupPresentationRequest) throws -> RedrawOutcome
    ) throws {
        for effect in effects {
            switch effect {
            case .performSoftwarePresent(let request):
                _ = try performSoftwarePresent(request)
            default:
                try interpretPopupEffects([effect])
            }
        }
    }

    private var popupEffectHandlers: PopupEffectHandlers {
        PopupEffectHandlers(
            ackConfigure: { [self] serial in
                try acknowledgeSurfaceConfigure(serial: serial)
                xdgSurface.ackConfigure(serial: serial)
            },
            publishDismissed: { [self] _ in
                onDismissed?()
                onDismissed = nil
            },
            publishClosed: { [self] _ in
                onClosed?()
                onClosed = nil
            },
            publishRedrawRequested: { [self] _ in
                onRedrawRequested?()
            },
            cancelFrameCallback: { [self] in
                pendingFrameRegistration = nil
                cancelSurfaceFrameCallback()
            },
            retireSwapchain: { [self] in
                retireSwapchain()
            },
            destroyRoleObjects: { [self] in
                try destroyRoleObjects()
            }
        )
    }

    private func destroyRoleObjects() throws {
        softwarePresentationCoordinator.close()
        presentationFeedbackCoordinator.close()
        onClose?()
        onClose = nil
        onRedrawRequested = nil

        destroyScaleResources()
        try destroyRoleResources()
    }
}
