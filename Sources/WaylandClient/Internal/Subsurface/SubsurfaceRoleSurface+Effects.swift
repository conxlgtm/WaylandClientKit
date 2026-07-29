extension SubsurfaceRoleSurface {
    func interpretSubsurfaceEffects(_ effects: [SubsurfaceEffect]) throws {
        try interpretSubsurfaceEffects(effects) { _ in
            throw SubsurfaceModelError.presentWithoutRedrawRequest
        }
    }

    func interpretSubsurfaceEffects(
        _ effects: [SubsurfaceEffect],
        performSoftwarePresent: (SubsurfacePresentationRequest) throws -> Void
    ) throws {
        for effect in effects {
            switch effect {
            case .publishRedrawRequested:
                onRedrawRequested?()
            case .performSoftwarePresent(let request):
                try performSoftwarePresent(request)
            case .cancelFrameCallback:
                pendingFrameRegistration = nil
                surfaceRuntime.cancelFrameCallback()
            case .retireSwapchain:
                surfaceRuntime.retireSharedMemoryPools(reason: .windowClosed)
            case .destroyRoleObjects:
                destroyRoleObjects()
            }
        }
    }

    private func destroyRoleObjects() {
        softwarePresentationCoordinator.close()
        presentationFeedbackCoordinator.close()
        surfaceRuntime.destroyScaleInstallation()
        let removedRoleResources = surfaceRuntime.removeRoleResources()
        removedRoleResources?.destroy()
        do {
            try surfaceRuntime.markSurfaceDestroyed()
        } catch {
            assertionFailure("subsurface surface runtime destroy failed: \(error)")
        }
    }
}
