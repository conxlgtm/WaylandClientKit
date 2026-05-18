import WaylandRaw

struct WindowSoftwarePresentationResult {
    let outcome: RedrawOutcome
    let followUp: WindowSoftwarePresentationFollowUp?
}

enum WindowSoftwarePresentationFollowUp {
    case fail(generation: UInt64, PresentationError)
    case blockedByBuffer
    case resetTransientState
    case succeeded(generation: UInt64)
}

struct WindowSoftwarePresentationFailure: Error {
    let presentationError: PresentationError
    let underlying: any Error
}

struct WindowSoftwarePresenter {
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let createSharedMemoryPool: (PositivePixelSize) throws -> RawSharedMemoryPool
    let isWindowClosed: () -> Bool
    let onFrame: () -> Void

    func present<RoleResources>(
        request: PresentationRequest,
        geometry: SurfaceGeometry,
        draw: (borrowing SoftwareFrame) throws -> Void,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) throws -> WindowSoftwarePresentationResult {
        guard pendingFrameRegistration == nil else {
            return .init(
                outcome: .skippedPendingFrame,
                followUp: .fail(
                    generation: request.generation,
                    .frameCallbackRequest("frame callback is still pending")
                )
            )
        }

        let pool = try runtime.sharedMemoryPool(for: geometry.bufferSize) {
            try createSharedMemoryPool(geometry.bufferSize)
        }
        runtime.dropReleasedRetiredBufferPools()

        guard var drawingBuffer = pool.acquireDrawingBuffer() else {
            return .init(outcome: .waitingForBuffer, followUp: .blockedByBuffer)
        }

        try drawFrame(&drawingBuffer, geometry: geometry, draw: draw)

        guard !isWindowClosed() else {
            drawingBuffer.discard()
            return .init(outcome: .skippedClosed, followUp: .resetTransientState)
        }

        let preparedCommit = try prepareCommit(
            request: request,
            geometry: geometry,
            runtime: &runtime,
            drawingBuffer: &drawingBuffer
        )
        try requestFrameCallback(
            request: request,
            runtime: &runtime,
            pendingFrameRegistration: &pendingFrameRegistration,
            drawingBuffer: &drawingBuffer
        )
        try recordAndCommit(
            preparedCommit,
            request: request,
            runtime: &runtime,
            pendingFrameRegistration: &pendingFrameRegistration,
            drawingBuffer: &drawingBuffer
        )

        return .init(
            outcome: .presented,
            followUp: .succeeded(generation: request.generation)
        )
    }

    private func drawFrame(
        _ drawingBuffer: inout RawBuffer.DrawingBuffer,
        geometry: SurfaceGeometry,
        draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        do {
            try unsafe drawingBuffer.withUnsafeMutableBytes { bytes in
                let frame = try unsafe SoftwareFrame(
                    width: drawingBuffer.width,
                    height: drawingBuffer.height,
                    stride: drawingBuffer.stride,
                    geometry: SoftwareFrameGeometry(surface: geometry),
                    bytes: bytes
                )
                try draw(frame)
            }
        } catch {
            drawingBuffer.discard()
            throw WindowSoftwarePresentationFailure(
                presentationError: .userDraw(String(describing: error)),
                underlying: error
            )
        }
    }

    private func prepareCommit<RoleResources>(
        request: PresentationRequest,
        geometry: SurfaceGeometry,
        runtime: inout SurfaceRuntime<RoleResources>,
        drawingBuffer: inout RawBuffer.DrawingBuffer
    ) throws -> PreparedSurfaceFrameCommit {
        do {
            return try SurfaceFrameCommitter.prepare(
                SurfaceFrameCommitRequest(
                    surface: surface,
                    scaleInstallation: scaleInstallation,
                    generation: request.generation,
                    geometry: geometry
                ),
                runtime: &runtime,
            )
        } catch {
            drawingBuffer.discard()
            throw WindowSoftwarePresentationFailure(
                presentationError: .surfaceCommit(String(describing: error)),
                underlying: error
            )
        }
    }

    private func requestFrameCallback<RoleResources>(
        request: PresentationRequest,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?,
        drawingBuffer: inout RawBuffer.DrawingBuffer
    ) throws {
        do {
            pendingFrameRegistration = try SurfaceFrameCommitter.requestFrameCallback(
                on: surface,
                runtime: &runtime,
                generation: request.generation,
                onFrame: onFrame
            )
        } catch {
            drawingBuffer.discard()
            throw WindowSoftwarePresentationFailure(
                presentationError: .frameCallbackRequest(String(describing: error)),
                underlying: error
            )
        }
    }

    private func recordAndCommit<RoleResources>(
        _ preparedCommit: PreparedSurfaceFrameCommit,
        request: PresentationRequest,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?,
        drawingBuffer: inout RawBuffer.DrawingBuffer
    ) throws {
        do {
            let buffer = drawingBuffer.markBusy(commitGeneration: request.generation)
            try SurfaceFrameCommitter.commit(
                preparedCommit,
                buffer: buffer,
                runtime: &runtime
            )
        } catch {
            pendingFrameRegistration = nil
            runtime.cancelFrameCallback()
            drawingBuffer.discard()
            throw WindowSoftwarePresentationFailure(
                presentationError: .surfaceCommit(String(describing: error)),
                underlying: error
            )
        }
    }
}
