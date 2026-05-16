import WaylandRaw

struct WindowSoftwarePresenter {
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let geometryForLogicalSize: (PositiveLogicalSize) throws -> SurfaceGeometry
    let bufferPool: (PositivePixelSize) throws -> RawSharedMemoryPool
    let isWindowClosed: () -> Bool
    let dropReleasedRetiredPools: () -> Void
    let onFrame: () -> Void
    let failActivePresentation: (UInt64, PresentationError) -> Void
    let onPresentationBlockedByBuffer: () throws -> Void
    let onTransientStateReset: () throws -> Void
    let onPresentationSucceeded: (UInt64) throws -> Void

    func present<RoleResources>(
        request: PresentationRequest,
        draw: (borrowing SoftwareFrame) throws -> Void,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) throws -> RedrawOutcome {
        guard pendingFrameRegistration == nil else {
            failActivePresentation(
                request.generation,
                .frameCallbackRequest("frame callback is still pending")
            )
            return .skippedPendingFrame
        }

        let geometry = try geometryForLogicalSize(request.configuration.size)
        let pool = try bufferPool(geometry.bufferSize)
        dropReleasedRetiredPools()

        guard var drawingBuffer = pool.acquireDrawingBuffer() else {
            try onPresentationBlockedByBuffer()
            return .waitingForBuffer
        }

        try drawFrame(&drawingBuffer, request: request, geometry: geometry, draw: draw)

        guard !isWindowClosed() else {
            try onTransientStateReset()
            drawingBuffer.discard()
            return .skippedClosed
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

        try onPresentationSucceeded(request.generation)
        return .presented
    }

    private func drawFrame(
        _ drawingBuffer: inout RawBuffer.DrawingBuffer,
        request: PresentationRequest,
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
            failActivePresentation(
                request.generation,
                .userDraw(String(describing: error))
            )
            drawingBuffer.discard()
            throw error
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
            failActivePresentation(
                request.generation,
                .surfaceCommit(String(describing: error))
            )
            drawingBuffer.discard()
            throw error
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
            failActivePresentation(
                request.generation,
                .frameCallbackRequest(String(describing: error))
            )
            drawingBuffer.discard()
            throw error
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
            try SurfaceFrameCommitter.recordPreparedCommit(
                preparedCommit,
                runtime: &runtime
            )
            let buffer = drawingBuffer.markBusy(commitGeneration: request.generation)
            SurfaceFrameCommitter.commit(preparedCommit, buffer: buffer)
        } catch {
            pendingFrameRegistration = nil
            runtime.cancelFrameCallback()
            drawingBuffer.discard()
            throw error
        }
    }
}
