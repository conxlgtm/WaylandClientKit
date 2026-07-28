import WaylandClient

struct ManagedSurfaceSmokeRun {
    let display: WaylandDisplay

    func execute() async throws {
        let capabilities = try await display.capabilities()
        let requestsFeedback =
            capabilities.presentationTime.isAvailable
            && !CommandLine.arguments.contains("--skip-feedback")
        let window = try await display.createTopLevelWindow(
            configuration: try windowConfiguration()
        )

        try await presentWindow(window, requestsFeedback: requestsFeedback)
        let popup = try await window.createPopup(configuration: try popupConfiguration())
        try await presentPopup(popup, requestsFeedback: requestsFeedback)

        let synchronized = try await window.createSubsurface(
            configuration: try subsurfaceConfiguration(
                position: LogicalOffset(x: 20, y: 24),
                mode: .synchronized
            )
        )
        try await presentSubsurface(
            synchronized,
            label: "synchronized subsurface",
            color: 0x0040_9050,
            requestsFeedback: requestsFeedback
        )

        let desynchronized = try await window.createSubsurface(
            configuration: try subsurfaceConfiguration(
                position: LogicalOffset(x: 152, y: 24),
                mode: .desynchronized
            )
        )
        try await presentSubsurface(
            desynchronized,
            label: "desynchronized subsurface",
            color: 0x0090_5040,
            requestsFeedback: requestsFeedback
        )

        if CommandLine.arguments.contains("--skip-redraw-routing") {
            print("redraw routing: skipped for compositor evidence run")
        } else {
            try await routeRedraw(for: popup, color: 0x0080_50A0)
            try await routeRedraw(for: synchronized, color: 0x0050_A080)
            try await routeRedraw(for: desynchronized, color: 0x00A0_8050)
        }
        try await finishPopup(popup)

        await window.close()
        guard try await synchronized.isClosed, try await desynchronized.isClosed else {
            throw ManagedSurfaceSmokeError.parentCloseDidNotCascade
        }
        print("parent-close cascade: synchronized and desynchronized children closed")
        print("managed surface presentation smoke: PASS")
    }

    private func windowConfiguration() throws -> WindowConfiguration {
        try WindowConfiguration(
            title: "Managed Surface Presentation Smoke",
            appID: "managed-surface-presentation-smoke",
            initialWidth: 320,
            initialHeight: 220,
            closeRequestPolicy: .requestOnly
        )
    }

    private func popupConfiguration() throws -> PopupConfiguration {
        try PopupConfiguration(
            positioner: PopupPositioner(
                anchorRect: LogicalRect(x: 16, y: 16, width: 80, height: 48),
                size: PositiveLogicalSize(width: 112, height: 72),
                anchor: .bottomLeft,
                gravity: .bottomRight,
                constraintAdjustment: [.slideX, .slideY]
            )
        )
    }

    private func subsurfaceConfiguration(
        position: LogicalOffset,
        mode: SubsurfaceSynchronizationMode
    ) throws -> SubsurfaceConfiguration {
        SubsurfaceConfiguration(
            position: position,
            size: try PositiveLogicalSize(width: 104, height: 64),
            synchronizationMode: mode
        )
    }
}

enum ManagedSurfaceSmokeError: Error {
    case unexpectedPresentationOutcome(String, SoftwarePresentationOutcome)
    case eventStreamEnded(String)
    case presentationStreamEnded(String)
    case parentCloseDidNotCascade
}
