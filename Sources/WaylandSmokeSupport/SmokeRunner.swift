import WaylandClient

package enum SmokeRunner {
    package static func run(configuration: SmokeConfiguration = .init()) throws -> SmokeResult {
        let session = try DisplaySession.connect()
        let capabilities = session.capabilitiesOnOwnerThread()
        var runtimeFacts = runtimeFacts(capabilities: capabilities, session: session)
        for optionalProtocol in configuration.requestedOptionalProtocols {
            guard
                isAdvertised(
                    optionalProtocol,
                    capabilities: capabilities,
                    session: session
                )
            else {
                return .skippedOptionalProtocol(optionalProtocol)
            }
        }

        let window = try session.createTopLevelWindow(
            configuration: WindowConfiguration(
                title: "SwiftWayland Smoke",
                appID: "swift-wayland-smoke",
                initialWidth: 64,
                initialHeight: 64,
                bufferCount: 2
            )
        )
        defer { window.close() }

        try window.show(timeoutMilliseconds: configuration.timeoutMilliseconds) { frame in
            fill(frame)
        }
        runtimeFacts.surface = try surfaceFacts(for: window)
        runtimeFacts.backing = .shm

        try session.pumpEvents(
            timeoutMilliseconds: configuration.postCommitPumpMilliseconds
        )
        _ = session.drainInputEvents()

        if window.needsRedraw {
            return .frameCallbackObserved(runtimeFacts)
        }

        return .committedFrame(runtimeFacts)
    }

    private static func isAdvertised(
        _ optionalProtocol: SmokeOptionalProtocol,
        capabilities: WaylandCapabilities,
        session: DisplaySession
    ) -> Bool {
        switch optionalProtocol {
        case .linuxDmabuf:
            capabilities.linuxDmabuf.isAvailable
        case .linuxDrmSyncobj, .fifo, .commitTiming, .contentType, .alphaModifier,
            .tearingControl, .colorRepresentation, .colorManagement:
            session.isProtocolAdvertisedOnOwnerThread(
                named: optionalProtocol.interfaceName
            )
        }
    }

    private static func runtimeFacts(
        capabilities: WaylandCapabilities,
        session: DisplaySession
    ) -> SmokeRuntimeFacts {
        SmokeRuntimeFacts(
            syncobj: advertisedStatus(
                .linuxDrmSyncobj,
                capabilities: capabilities,
                session: session
            ),
            fifo: advertisedStatus(.fifo, capabilities: capabilities, session: session),
            commitTiming: advertisedStatus(
                .commitTiming,
                capabilities: capabilities,
                session: session
            ),
            dmabuf: capabilities.linuxDmabuf.isAvailable ? .advertised : .unavailable,
            gbm: .unavailable,
            egl: .unavailable,
            presentationFeedback: capabilities.presentationTime.isAvailable
                ? .advertised
                : .unavailable,
            contentType: advertisedStatus(
                .contentType,
                capabilities: capabilities,
                session: session
            ),
            alphaModifier: advertisedStatus(
                .alphaModifier,
                capabilities: capabilities,
                session: session
            ),
            tearingControl: advertisedStatus(
                .tearingControl,
                capabilities: capabilities,
                session: session
            ),
            colorRepresentation: advertisedStatus(
                .colorRepresentation,
                capabilities: capabilities,
                session: session
            ),
            colorManagement: advertisedStatus(
                .colorManagement,
                capabilities: capabilities,
                session: session
            )
        )
    }

    private static func surfaceFacts(for window: TopLevelWindow) throws -> SmokeSurfaceFacts {
        let geometry = try window.geometryOnOwnerThread
        let state = try window.stateSnapshotOnOwnerThread
        return SmokeSurfaceFacts(
            scale: geometry.scale.description,
            outputs: state.outputs.count
        )
    }

    private static func advertisedStatus(
        _ optionalProtocol: SmokeOptionalProtocol,
        capabilities: WaylandCapabilities,
        session: DisplaySession
    ) -> SmokePathStatus {
        isAdvertised(
            optionalProtocol,
            capabilities: capabilities,
            session: session
        ) ? .advertised : .unavailable
    }

    private static func fill(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for column in 0..<pixels.count {
                let red = UInt32((column * 255) / max(pixels.count, 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: column] = (red << 16) | (green << 8) | 0x40
            }
        }
    }
}
