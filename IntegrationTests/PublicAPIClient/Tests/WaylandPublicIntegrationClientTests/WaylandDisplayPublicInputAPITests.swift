import Testing
import WaylandClient

@Suite("WaylandDisplay public input API surface")
struct WaylandDisplayPublicInputAPITests {
    @Test
    func activationTypesAndMethodsCompileForExternalClients() throws {
        let token = try ActivationToken("opaque-token")
        let appID = try ActivationAppID("org.waylandclientkit.Client")
        let serialContext = ActivationSerialContext(
            seatID: SeatID(rawValue: 1),
            serial: InputSerial(rawValue: 2)
        )
        let request = ActivationTokenRequest(
            appID: appID,
            serialContext: serialContext
        )

        #expect(token.value == "opaque-token")
        #expect(appID.value == "org.waylandclientkit.Client")
        #expect(request.appID == appID)
        #expect(request.serialContext == serialContext)
        #expect(ActivationError.invalidToken.description.contains("activation token"))

        func useActivationAPI(display: WaylandDisplay, window: Window) async throws {
            let displayToken = try await display.requestActivationToken(
                ActivationTokenRequest(window: window),
                timeoutMilliseconds: 1
            )
            try await display.activate(window: window, token: displayToken)

            let windowToken = try await window.requestActivationToken(
                appID: "org.waylandclientkit.Client",
                timeoutMilliseconds: 1
            )
            try await window.activate(using: windowToken)
        }

        _ = useActivationAPI
    }

    @Test
    func pointerCaptureTypesAndMethodsCompileForExternalClients() throws {
        let region = PointerConstraintRegion(
            try LogicalRect(
                x: 0,
                y: 0,
                width: 20,
                height: 20
            )
        )
        let motion = RelativePointerMotionEvent(
            time: WaylandTimestampMicroseconds(rawValue: 10),
            delta: PointerDelta(dx: 1.5, dy: -2),
            unacceleratedDelta: PointerDelta(dx: 2, dy: -3)
        )

        #expect(region.rectangles.count == 1)
        #expect(motion.delta.dx == 1.5)
        #expect(PointerCaptureError.unavailable(.relativePointer).description.contains("relative"))
        let constraintID = PointerConstraintID(rawValue: 7, kind: .locked)
        let lifecycleEvents: [PointerEvent] = [
            .constraintLifecycle(.activated(constraintID)),
            .constraintLifecycle(.inactivePersistent(constraintID)),
            .constraintLifecycle(.defunctOneShot(constraintID)),
        ]
        let lifecycleNames = lifecycleEvents.map { event in
            switch event {
            case .constraintLifecycle(.activated):
                "activated"
            case .constraintLifecycle(.inactivePersistent):
                "inactivePersistent"
            case .constraintLifecycle(.defunctOneShot):
                "defunctOneShot"
            default:
                "other"
            }
        }
        #expect(lifecycleNames == ["activated", "inactivePersistent", "defunctOneShot"])

        func usePointerCaptureAPI(display: WaylandDisplay, window: Window, seatID: SeatID)
            async throws
        {
            let subscription = try await display.relativePointer(seatID: seatID)
            try await subscription.destroy()

            let displayConstraint = try await display.lockPointer(
                window: window,
                seatID: seatID,
                region: region,
                lifetime: .oneShot
            )
            try await displayConstraint.destroy()

            let windowConstraint = try await window.confinePointer(
                seatID: seatID,
                region: region,
                lifetime: .persistent
            )
            try await windowConstraint.destroy()
        }

        _ = usePointerCaptureAPI
    }

    @Test
    func cursorPolicyTypesCompileForExternalClients() throws {
        let configuration = CursorConfiguration(
            scalePolicy: .matchFocusedOutput,
            fallbackCursor: .crosshair
        )
        let named = try PointerCursor(name: "nw-resize")

        #expect(configuration.scalePolicy == .matchFocusedOutput)
        #expect(named.name == "nw-resize")
    }
}
