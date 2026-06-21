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

        #expect(configuration.presentationMode == .managedGPU)
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
    func externalBufferRegistrationTypesCompileForExternalClients() async throws {
        func registerExternalBuffer(
            backing: WaylandGraphicsWindowBacking,
            lease: WaylandGraphicsFrameLease
        ) async throws {
            let configurationID = try #require(
                lease.contract.recommendedExternalConfigurationID)
            _ = try externalClientTwoPlaneDescriptor(size: lease.size)
            let descriptor = try externalClientDescriptor(size: lease.size)
            let buffer = try await backing.registerExternalBuffer(
                descriptor,
                contract: lease.contract,
                configurationID: configurationID
            )
            let renderLease = try await lease.reserveExternalBuffer(buffer)
            let receipt = try await renderLease.submit()
            _ = receipt.id
            _ = await receipt.waitForRelease()
        }

        func submitExternalBufferWithExplicitSync(
            renderLease: WaylandGraphicsExternalBufferRenderLease,
            timeline: WaylandGraphicsExternalSyncTimeline
        ) async throws {
            let point = WaylandGraphicsExternalSyncPoint(timeline: timeline, value: 1)
            _ = try await renderLease.submit(
                acquireSynchronization: .drmSyncobj(point)
            )
        }

        func importExternalSyncTimeline(
            backing: WaylandGraphicsWindowBacking
        ) async throws -> WaylandGraphicsExternalSyncTimeline {
            try await backing.importExternalSyncTimeline(
                try externalClientPipeDescriptor()
            )
        }

        _ = registerExternalBuffer
        _ = submitExternalBufferWithExplicitSync
        _ = importExternalSyncTimeline
    }

    @Test
    func externalGPUPresentationConfigurationCompilesForExternalClients() {
        let configuration = WaylandGraphicsConfiguration(
            presentationMode: .externalGPU,
            fallbackPolicy: .requireGPU,
            synchronizationPolicy: .preferExplicit,
            pacingPolicy: .preferFIFO,
            metadataPolicy: .preferAvailable,
            presentationFeedbackPolicy: .requestWhenAvailable
        )

        #expect(configuration.presentationMode == .externalGPU)
        #expect(configuration.backingPreference == .managedGPU)
        #expect(configuration.fallbackPolicy == .requireGPU)
    }
}

private func externalClientDescriptor(
    size: PositivePixelSize
) throws -> WaylandGraphicsExternalBufferDescriptor {
    let stride = UInt32(size.width.rawValue) * 4
    let plane = try WaylandGraphicsExternalBufferPlane(
        fileDescriptor: try externalClientPipeDescriptor(),
        offset: 0,
        stride: stride
    )
    return try WaylandGraphicsExternalBufferDescriptor(
        size: size,
        format: .xrgb8888,
        modifier: .linear,
        plane: plane
    )
}

private func externalClientTwoPlaneDescriptor(
    size: PositivePixelSize
) throws -> WaylandGraphicsExternalBufferDescriptor {
    let stride = UInt32(size.width.rawValue) * 4
    let firstPlane = try WaylandGraphicsExternalBufferPlane(
        fileDescriptor: try externalClientPipeDescriptor(),
        offset: 0,
        stride: stride,
        planeIndex: 0
    )
    let secondPlane = try WaylandGraphicsExternalBufferPlane(
        fileDescriptor: try externalClientPipeDescriptor(),
        offset: 0,
        stride: stride,
        planeIndex: 1
    )
    return try WaylandGraphicsExternalBufferDescriptor(
        size: size,
        format: .xrgb8888,
        modifier: .linear,
        plane0: firstPlane,
        plane1: secondPlane
    )
}

private func externalClientPipeDescriptor() throws -> OwnedFileDescriptor {
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
