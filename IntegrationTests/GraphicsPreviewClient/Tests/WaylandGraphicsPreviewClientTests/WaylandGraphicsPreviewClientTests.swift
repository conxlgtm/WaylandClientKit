import Glibc
import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsPreviewClientTests {
    @Test
    func graphicsPreviewTypesCompileForExternalClients() throws {
        let clientCapabilities = WaylandCapabilities(
            clipboard: .unavailable,
            dragAndDrop: .unavailable,
            dragActionNegotiation: .unavailable,
            primarySelection: .unavailable,
            xdgDecoration: .unavailable,
            xdgOutput: .unavailable,
            viewporter: .unavailable,
            presentationTime: .available(version: 1),
            fractionalScale: .unavailable,
            cursorShape: .unavailable,
            xdgActivation: .unavailable,
            relativePointer: .unavailable,
            pointerConstraints: .unavailable,
            textInput: .unavailable,
            linuxDmabuf: .unavailable
        )

        #expect(clientCapabilities.xdgActivation == .unavailable)
        #expect(clientCapabilities.relativePointer == .unavailable)
        #expect(clientCapabilities.pointerConstraints == .unavailable)

        let capabilities = WaylandGraphicsSurfaceCapabilities(
            capabilities: clientCapabilities
        )
        let path = WaylandGraphicsRuntimePath.projected(
            capabilities: capabilities,
            policy: .preferGPUFallbackToSoftware
        )
        let decision = WaylandGraphicsFallbackPolicy.requireGPU.decide(
            capabilities: capabilities
        )

        #expect(path.backing == .fallback(.dmabufUnavailable))
        #expect(decision == .unavailable(.dmabufUnavailable))
    }

    @Test
    func displayGraphicsPreviewMethodsAreAvailableToExternalClients() async throws {
        func acceptsDisplay(_ display: WaylandDisplay) async throws {
            _ = try await display.graphicsSurfaceCapabilities()
            _ = try await display.graphicsRuntimePath(policy: .forceSoftware)
            _ = try await display.graphicsBackingDecision(policy: .requireGPU)
            let backing = try await display.createGraphicsWindowBacking(
                windowConfiguration: WindowConfiguration(
                    title: "Graphics Preview Client",
                    appID: "graphics-preview-client",
                    initialWidth: 16,
                    initialHeight: 16
                ),
                graphicsConfiguration: WaylandGraphicsConfiguration(
                    fallbackPolicy: .forceSoftware,
                    backingPreference: .software
                )
            )
            _ = backing.window
            _ = try await backing.runtimePath
            let lease = try await backing.nextFrame()
            let result = try await lease.submit(
                .clearColor(WaylandGraphicsXRGBColor(red: 0, green: 0, blue: 0))
            )
            _ = result.runtimePath
            _ = result.size
            try await backing.close()
        }

        _ = acceptsDisplay
    }

    @Test
    func managedPreviewSubmissionTypesCompileForExternalClients() throws {
        let configuration = WaylandGraphicsConfiguration(
            fallbackPolicy: .preferGPUFallbackToSoftware,
            backingPreference: .managedGPU,
            synchronizationPolicy: .preferExplicit,
            pacingPolicy: .preferFIFO,
            metadataPolicy: .preferAvailable,
            presentationFeedbackPolicy: .requestWhenAvailable
        )
        let metadata = WaylandGraphicsFrameMetadata(
            contentType: .video,
            presentationHint: .async,
            alpha: .opaque,
            colorRepresentation: WaylandGraphicsColorRepresentation(
                alphaMode: .premultipliedElectrical
            ),
            damage: .fullFrame
        )
        let schedule = WaylandGraphicsFrameSchedule(
            synchronization: .preferExplicit,
            pacing: .fifo,
            presentationFeedback: .requestWhenAvailable
        )
        let frame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsXRGBColor(red: 1, green: 2, blue: 3)
        )
        let expectedFrame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsClearFrame(
                color: WaylandGraphicsXRGBColor(red: 1, green: 2, blue: 3)
            )
        )
        let submissionFailure = WaylandGraphicsSubmissionFailure.unexpected(
            operation: .show,
            stage: .frameSubmission,
            description: "external client diagnostic"
        )
        let result = WaylandGraphicsFrameResult(
            runtimePath: externalClientSoftwareRuntimePath(),
            operation: .show,
            size: try PositivePixelSize(width: 1, height: 1),
            metadata: metadata,
            schedule: schedule,
            presentationFeedbackRequested: true,
            synchronizationPolicy: .preferExplicit,
            pacingPolicy: .preferFIFO
        )

        #expect(configuration.backingPreference == .managedGPU)
        #expect(configuration.synchronizationPolicy == .preferExplicit)
        #expect(configuration.presentationFeedbackPolicy == .requestWhenAvailable)
        #expect(WaylandGraphicsFallbackReason.surfaceFeedbackUnavailable != .dmabufUnavailable)
        #expect(WaylandGraphicsUnavailableReason.gbmAllocationFailed != .gbmUnavailable)
        #expect(metadata.contentType == .video)
        #expect(metadata.alpha == .opaque)
        #expect(metadata.damage == .fullFrame)
        #expect(frame == expectedFrame)
        #expect(result.operation == .show)
        #expect(result.backing == .fallback(.forcedSoftware))
        #expect(result.metadata == metadata)
        #expect(result.schedule == schedule)
        #expect(result.presentationFeedbackRequested)
        #expect(result.synchronizationPolicy == .preferExplicit)
        #expect(result.pacingPolicy == .preferFIFO)
        #expect(
            WaylandGraphicsError.submissionFailed(submissionFailure)
                == .submissionFailed(submissionFailure))
    }

    @Test
    func softwareSubmissionClosureCompilesForExternalClients() async throws {
        func submitSoftwareFrame(backing: WaylandGraphicsWindowBacking) async throws {
            let firstLease = try await backing.nextFrame()
            await firstLease.cancel()

            let secondLease = try await backing.nextFrame()
            let result = try await secondLease.submitSoftware(
                metadata: WaylandGraphicsFrameMetadata(damage: .fullFrame)
            ) { frame in
                frame.withXRGB8888Rows { _, pixels in
                    for index in 0..<pixels.count {
                        pixels[unchecked: index] = 0x0010_2030
                    }
                }
            }
            #expect(result.operation == .show || result.operation == .redraw)
        }

        _ = submitSoftwareFrame
    }

    @Test
    func externalBufferSubmissionTypesCompileForExternalClients() async throws {
        func submitExternalBuffer(lease: WaylandGraphicsFrameLease) async throws {
            let result = try await lease.submitExternalBuffer(
                try externalClientBufferDescriptor(),
                metadata: WaylandGraphicsFrameMetadata(
                    contentType: .game,
                    alpha: .opaque
                ),
                synchronization: .default,
                schedule: WaylandGraphicsFrameSchedule(
                    pacing: .commitTiming(.default),
                    presentationFeedback: .requestWhenAvailable
                )
            )
            _ = result.runtimePath
        }

        _ = submitExternalBuffer
    }
}

private func externalClientBufferDescriptor() throws
    -> WaylandGraphicsExternalBufferDescriptor
{
    let plane = try WaylandGraphicsExternalBufferPlane(
        fd: try externalClientOwnedDescriptor(),
        offset: 0,
        stride: 4,
        planeIndex: 0
    )
    return try WaylandGraphicsExternalBufferDescriptor(
        size: PositivePixelSize(width: 1, height: 1),
        format: WaylandGraphicsDRMFormat(rawValue: 875_713_112),
        modifier: WaylandGraphicsDRMFormatModifier(rawValue: 0),
        planes: .one(plane)
    )
}

private func externalClientOwnedDescriptor() throws -> OwnedFileDescriptor {
    var descriptors = [Int32](repeating: -1, count: 2)
    let result = unsafe descriptors.withUnsafeMutableBufferPointer { buffer in
        unsafe Glibc.pipe(buffer.baseAddress)
    }
    guard result == 0 else {
        throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
    }

    Glibc.close(descriptors[1])
    return try OwnedFileDescriptor(adopting: descriptors[0])
}

private func externalClientSoftwareRuntimePath() -> WaylandGraphicsRuntimePath {
    WaylandGraphicsRuntimePath.projected(
        capabilities: WaylandGraphicsSurfaceCapabilities(
            capabilities: WaylandCapabilities(
                clipboard: .unavailable,
                dragAndDrop: .unavailable,
                dragActionNegotiation: .unavailable,
                primarySelection: .unavailable,
                xdgDecoration: .unavailable,
                xdgOutput: .unavailable,
                viewporter: .unavailable,
                presentationTime: .unavailable,
                fractionalScale: .unavailable,
                cursorShape: .unavailable,
                xdgActivation: .unavailable,
                relativePointer: .unavailable,
                pointerConstraints: .unavailable,
                textInput: .unavailable,
                linuxDmabuf: .unavailable
            )
        ),
        policy: .forceSoftware
    )
}
