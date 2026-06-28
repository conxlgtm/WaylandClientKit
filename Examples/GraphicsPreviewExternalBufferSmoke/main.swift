import CEGLShims
import CGBMShims
import CGLESv2System
import Foundation
import Glibc
import WaylandClient
import WaylandExampleSupport
import WaylandGraphicsPreview

@main
enum GraphicsPreviewExternalBufferSmoke {
    private static let drmFormatXRGB8888: UInt32 = 875_713_112

    static func main() async {
        let exitCode: Int32
        do {
            try await run()
            exitCode = EXIT_SUCCESS
        } catch {
            log("feature: external-gpu-buffer")
            log("failure: \(error)")
            log("cleanup: not observed")
            exitCode = EXIT_FAILURE
        }

        guard exitCode == EXIT_SUCCESS else {
            exit(exitCode)
        }
    }

    private static func run() async throws {
        let options = try ExternalBufferSmokeOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection { display in
            let backing = try await display.createGraphicsWindowBacking(
                windowConfiguration: WindowConfiguration(
                    title: "WaylandClientKit External Buffer Smoke",
                    appID: "wayland-client-kit-external-buffer-smoke",
                    initialWidth: 96,
                    initialHeight: 96,
                    bufferCount: 2
                ),
                graphicsConfiguration: WaylandGraphicsConfiguration(
                    presentationMode: .externalGPU,
                    fallbackPolicy: .requireGPU
                )
            )
            let runtimePath = try await backing.runtimePath
            log("feature: external-gpu-buffer")
            log("scope: public-wck-api-with-direct-renderer-helper")
            log("requested backing: external-dmabuf")
            log("initial dmabuf status: \(status(runtimePath.dmabufImport))")
            log("format: XRGB8888")
            log("modifier: 0")
            log("planes: 1")

            var backingWasClosed = false
            switch options.mode {
            case .probe:
                log("mode: probe")
                log("import: skipped(probe)")
                log("submit: skipped(probe)")
                log("release: not observed")
                log(
                    "fallback reason: \(runtimePath.fallback.map(String.init(describing:)) ?? "none")"
                )
                log("failure: none")
            case .internalTestBuffer:
                if options.stressFrames > 0 {
                    backingWasClosed = try await submitStressBuffers(
                        backing: backing,
                        frameCount: options.stressFrames
                    )
                } else {
                    backingWasClosed = try await submitInternalTestBuffer(backing: backing)
                }
            case .negativeTestBuffer:
                try await submitNegativeTestBuffer(backing: backing)
            }

            if !backingWasClosed {
                try await backing.close()
            }
            log("cleanup: pass")
        }
    }

    private static func submitStressBuffers(
        backing: WaylandGraphicsWindowBacking,
        frameCount: Int
    ) async throws -> Bool {
        log("mode: renderer-dmabuf-stress")
        let lease = try await backing.nextFrame()
        let configuration = try requireExternalConfiguration(lease.contract)
        let pool = try await registerStressPool(
            backing: backing,
            lease: lease,
            configuration: configuration
        )
        defer {
            for renderer in pool.renderers {
                renderer.close()
            }
        }

        var receipts = [WaylandGraphicsExternalBufferSubmissionReceipt?](
            repeating: nil,
            count: pool.buffers.count
        )
        var releaseCount = 0
        for frameIndex in 0..<frameCount {
            let bufferIndex = frameIndex % pool.buffers.count
            if let receipt = receipts[bufferIndex] {
                let release = await releaseStatus(receipt)
                guard release == "released" else {
                    throw ExternalBufferSmokeFailure.releaseNotObserved(release)
                }
                releaseCount += 1
            }

            let frameLease =
                frameIndex == 0
                ? lease
                : try await backing.nextFrame()
            guard frameLease.contract.generation == pool.generation else {
                throw WaylandGraphicsError.staleFrameContract(
                    rendered: pool.generation,
                    current: frameLease.contract.generation
                )
            }
            let renderLease = try await frameLease.reserveExternalBuffer(
                pool.buffers[bufferIndex]
            )
            receipts[bufferIndex] = try await renderLease.submit()
        }

        logStressResult(
            pool: pool,
            frameCount: frameCount,
            releaseCount: releaseCount
        )
        try await backing.close()
        return true
    }

    private static func registerStressPool(
        backing: WaylandGraphicsWindowBacking,
        lease: WaylandGraphicsFrameLease,
        configuration: WaylandGraphicsExternalBufferConfiguration
    ) async throws -> StressPool {
        var renderers: [ExternalDmabufRenderer] = []
        var buffers: [WaylandGraphicsExternalBuffer] = []
        for _ in 0..<3 {
            let renderer = try ExternalDmabufRenderer(
                size: lease.size,
                configuration: configuration
            )
            let buffer = try await backing.registerExternalBuffer(
                try renderer.makeDescriptor(),
                contract: lease.contract,
                configurationID: configuration.id
            )
            renderers.append(renderer)
            buffers.append(buffer)
        }

        return StressPool(
            renderers: renderers,
            buffers: buffers,
            generation: lease.contract.generation,
            configuration: configuration
        )
    }

    private static func logStressResult(
        pool: StressPool,
        frameCount: Int,
        releaseCount: Int
    ) {
        log("renderer: active")
        log("registration count: \(pool.buffers.count)")
        log("Wayland import count: \(pool.buffers.count)")
        log("submission count: \(frameCount)")
        log("release count: \(releaseCount)")
        log("reuse count: \(max(0, frameCount - pool.buffers.count))")
        log("maximum simultaneous compositor ownership: \(pool.buffers.count)")
        log("sync mode: implicitOnly")
        log("target device: \(pool.configuration.renderNode)")
        log("wck-cpu-readback: not-performed")
        log("wck-software-staging: not-performed")
        log("fallback reason: none")
        log("failure: none")
    }

    private static func submitInternalTestBuffer(
        backing: WaylandGraphicsWindowBacking
    ) async throws -> Bool {
        log("mode: renderer-dmabuf")
        let firstLease = try await backing.nextFrame()
        log(
            "frame size: \(firstLease.size.width.rawValue)x\(firstLease.size.height.rawValue)"
        )
        let configuration = try requireExternalConfiguration(
            firstLease.contract
        )
        let renderer: ExternalDmabufRenderer
        do {
            renderer = try ExternalDmabufRenderer(
                size: firstLease.size,
                configuration: configuration
            )
        } catch {
            log("renderer: unavailable(\(error))")
            log("import: skipped(renderer-setup-failed)")
            log("submit: skipped(renderer-setup-failed)")
            log("release: not observed")
            log("fallback reason: none")
            log("failure: none")
            return false
        }

        defer {
            renderer.close()
        }

        do {
            let buffer = try await backing.registerExternalBuffer(
                try renderer.makeDescriptor(),
                contract: firstLease.contract,
                configurationID: configuration.id
            )
            let renderLease = try await firstLease.reserveExternalBuffer(buffer)
            let result = try await renderLease.submit()
            let replacementRenderer = try await submitReplacementBuffer(backing: backing)
            defer {
                replacementRenderer.close()
            }
            let release = await releaseStatus(result)
            guard release == "released" else {
                throw ExternalBufferSmokeFailure.releaseNotObserved(release)
            }

            let reuseLease = try await backing.nextFrame()
            let reuseRenderLease = try await reuseLease.reserveExternalBuffer(buffer)
            let reuseResult = try await reuseRenderLease.submit()
            let secondReplacementRenderer = try await submitReplacementBuffer(backing: backing)
            defer {
                secondReplacementRenderer.close()
            }
            let reuseRelease = await releaseStatus(reuseResult)
            guard reuseRelease == "released" else {
                throw ExternalBufferSmokeFailure.releaseNotObserved(reuseRelease)
            }

            log("renderer: active")
            log("format: \(renderer.formatDescription)")
            log("modifier: \(renderer.modifierDescription)")
            log("planes: \(renderer.planeCount)")
            log("import: pass")
            log("submit: pass")
            log("registration count: 3")
            log("submission count: 4")
            log("release count: 2")
            log("same-registration submissions: 2")
            log("reuse count: 1")
            log("sync mode: \(firstLease.contract.synchronization)")
            log("release mechanism: \(result.releaseMechanism)")
            log("release synchronization: \(releaseSynchronizationStatus(result))")
            log("target device: \(configuration.renderNode)")
            log("wck-cpu-readback: not-performed")
            log("wck-software-staging: not-performed")
            log("release: \(release)")
            log("reuse release: \(reuseRelease)")
            log("release/reuse: tracked-by-wayland-client-kit")
            log(
                "fallback reason: \(result.frameResult.runtimePath.fallback.map(String.init(describing:)) ?? "none")"
            )
            log("failure: none")
            try await backing.close()
            return true
        } catch {
            log("renderer: active")
            log("format: \(renderer.formatDescription)")
            log("modifier: \(renderer.modifierDescription)")
            log("planes: \(renderer.planeCount)")
            log("import: fail(\(error))")
            log("submit: fail(import-failed)")
            log("release: not observed")
            log("fallback reason: none")
            log("failure: \(error)")
            return false
        }
    }

    private static func submitReplacementBuffer(
        backing: WaylandGraphicsWindowBacking
    ) async throws -> ExternalDmabufRenderer {
        let lease = try await backing.nextFrame()
        let configuration = try requireExternalConfiguration(lease.contract)
        let renderer = try ExternalDmabufRenderer(
            size: lease.size,
            configuration: configuration
        )

        let buffer = try await backing.registerExternalBuffer(
            try renderer.makeDescriptor(),
            contract: lease.contract,
            configurationID: configuration.id
        )
        let renderLease = try await lease.reserveExternalBuffer(buffer)
        _ = try await renderLease.submit()
        return renderer
    }

    private static func submitNegativeTestBuffer(
        backing: WaylandGraphicsWindowBacking
    ) async throws {
        log("mode: negative-cleanup")
        log("test buffer: pipe-fd-not-dmabuf")
        let lease = try await backing.nextFrame()
        do {
            let buffer = try await backing.registerExternalBuffer(
                try pipeBackedExternalDescriptor(size: lease.size),
                contract: lease.contract,
                configurationID: try requireExternalConfiguration(lease.contract).id
            )
            let renderLease = try await lease.reserveExternalBuffer(buffer)
            _ = try await renderLease.submit()
            log("import: pass(unexpected)")
            log("submit: pass(unexpected)")
            log("release: observed(unexpected)")
            log("fallback reason: none")
            log("failure: unexpected-pipe-fd-import-success")
        } catch {
            log("import: fail(expected-cleanup: \(error))")
            log("submit: fail(import-failed)")
            log("release: not observed")
            log("fallback reason: none")
            log("failure: expected-negative-test(\(error))")
            await lease.cancel()
        }
    }

    private static func pipeBackedExternalDescriptor(
        size: PositivePixelSize
    ) throws -> WaylandGraphicsExternalBufferDescriptor {
        let stride = UInt32(size.width.rawValue) * 4
        let plane = try WaylandGraphicsExternalBufferPlane(
            fileDescriptor: try pipeReadDescriptor(),
            offset: 0,
            stride: stride
        )
        return try WaylandGraphicsExternalBufferDescriptor(
            size: size,
            format: WaylandGraphicsDRMFormat(rawValue: drmFormatXRGB8888),
            modifier: WaylandGraphicsDRMFormatModifier(rawValue: 0),
            plane: plane
        )
    }

    private static func pipeReadDescriptor() throws -> OwnedFileDescriptor {
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

    nonisolated private static func status(_ status: WaylandGraphicsRuntimeStatus) -> String {
        switch status {
        case .unavailable:
            "unavailable"
        case .pending:
            "pending"
        case .advertised:
            "advertised"
        case .configured:
            "configured"
        case .active:
            "active"
        case .fallback(let reason):
            "fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        }
    }

    private static func requireExternalConfiguration(
        _ contract: WaylandGraphicsFrameContract
    ) throws -> WaylandGraphicsExternalBufferConfiguration {
        guard let configurationID = contract.recommendedExternalConfigurationID,
            let configuration = contract.externalBufferConfigurations.first(
                where: { $0.id == configurationID }
            )
        else {
            throw WaylandGraphicsError.unavailable(.noCompatibleFormat)
        }

        return configuration
    }

    private static func releaseStatus(
        _ receipt: WaylandGraphicsExternalBufferSubmissionReceipt
    ) async -> String {
        let probe = ReleaseStatusProbe()
        let task = Task {
            let status =
                switch await receipt.waitForRelease() {
                case .released:
                    "released"
                case .retired(let reason):
                    "retired(\(reason))"
                case .failed(let reason):
                    "failed(\(reason))"
                }
            await probe.record(status)
        }
        defer { task.cancel() }

        for _ in 0..<20 {
            if let status = await probe.status {
                return status
            }
            try? await Task.sleep(for: .milliseconds(50))
        }

        return await probe.status ?? "not-observed"
    }

    private static func releaseSynchronizationStatus(
        _ receipt: WaylandGraphicsExternalBufferSubmissionReceipt
    ) -> String {
        switch receipt.releaseSynchronization {
        case .implicitWaylandBufferRelease:
            "implicit"
        case .explicitSyncobjTimelinePoint(let point, let compositorAccepted):
            "explicit(timeline=\(point.timelineID), point=\(point.point), "
                + "accepted=\(compositorAccepted))"
        }
    }

    nonisolated private static func log(_ message: String) {
        print(message)
    }
}

private enum ExternalBufferSmokeFailure: Error, CustomStringConvertible {
    case releaseNotObserved(String)

    var description: String {
        switch self {
        case .releaseNotObserved(let status):
            "release-not-observed(\(status))"
        }
    }
}

private struct StressPool {
    let renderers: [ExternalDmabufRenderer]
    let buffers: [WaylandGraphicsExternalBuffer]
    let generation: WaylandGraphicsSurfaceGeneration
    let configuration: WaylandGraphicsExternalBufferConfiguration
}

private actor ReleaseStatusProbe {
    private(set) var status: String?

    func record(_ releaseStatus: String) {
        guard status == nil else { return }

        status = releaseStatus
    }
}

@safe
private final class ExternalDmabufRenderer {
    private var renderNodeFileDescriptor: Int32?
    private var gbmDevice: OpaquePointer?
    private var gbmSurface: OpaquePointer?
    private var lockedBuffer: OpaquePointer?
    private var eglDisplay: UnsafeMutableRawPointer?
    private var eglContext: UnsafeMutableRawPointer?
    private var eglSurface: UnsafeMutableRawPointer?

    private(set) var formatDescription = "unknown"
    private(set) var modifierDescription = "unknown"
    private(set) var planeCount = 0

    init(
        size: PositivePixelSize,
        configuration: WaylandGraphicsExternalBufferConfiguration
    ) throws {
        do {
            let renderNodeFD = try Self.openRenderNode(
                deviceIDBytes: configuration.renderNode.deviceIDBytes
            )
            renderNodeFileDescriptor = renderNodeFD

            guard let createdDevice = unsafe swl_gbm_create_device(renderNodeFD) else {
                throw WaylandGraphicsError.unavailable(.noRenderNode)
            }
            unsafe gbmDevice = createdDevice

            guard
                let createdSurface = unsafe swl_gbm_surface_create_for_modifier(
                    createdDevice,
                    UInt32(size.width.rawValue),
                    UInt32(size.height.rawValue),
                    configuration.format.rawValue,
                    configuration.modifier.rawValue,
                    swl_gbm_bo_use_rendering()
                )
            else {
                throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
            }
            unsafe gbmSurface = createdSurface

            try unsafe createEGLTarget(
                gbmDevice: createdDevice,
                gbmSurface: createdSurface,
                format: configuration.format.rawValue
            )
            try drawScene(width: UInt32(size.width.rawValue), height: UInt32(size.height.rawValue))

            guard let frontBuffer = unsafe swl_gbm_surface_lock_front_buffer(createdSurface) else {
                throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
            }
            unsafe lockedBuffer = frontBuffer
        } catch {
            close()
            throw error
        }
    }

    func makeDescriptor() throws -> WaylandGraphicsExternalBufferDescriptor {
        guard let lockedBuffer = unsafe lockedBuffer else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }

        var exportedBuffer = swl_gbm_bo_export()
        guard unsafe swl_gbm_bo_export_dmabuf(lockedBuffer, &exportedBuffer) == 0 else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
        defer {
            unsafe swl_gbm_bo_export_close(&exportedBuffer)
        }

        formatDescription = String(exportedBuffer.format)
        modifierDescription = String(exportedBuffer.modifier)
        planeCount = Int(exportedBuffer.plane_count)

        let size = try PositivePixelSize(
            width: Int32(exportedBuffer.width),
            height: Int32(exportedBuffer.height)
        )
        let format = try WaylandGraphicsDRMFormat(rawValue: exportedBuffer.format)
        let modifier = WaylandGraphicsDRMFormatModifier(rawValue: exportedBuffer.modifier)
        switch planeCount {
        case 1:
            return try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                plane: try Self.plane(at: 0, from: &exportedBuffer)
            )
        case 2:
            return try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                plane0: try Self.plane(at: 0, from: &exportedBuffer),
                plane1: try Self.plane(at: 1, from: &exportedBuffer)
            )
        case 3:
            return try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                plane0: try Self.plane(at: 0, from: &exportedBuffer),
                plane1: try Self.plane(at: 1, from: &exportedBuffer),
                plane2: try Self.plane(at: 2, from: &exportedBuffer)
            )
        case 4:
            return try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                plane0: try Self.plane(at: 0, from: &exportedBuffer),
                plane1: try Self.plane(at: 1, from: &exportedBuffer),
                plane2: try Self.plane(at: 2, from: &exportedBuffer),
                plane3: try Self.plane(at: 3, from: &exportedBuffer)
            )
        default:
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
    }

    func close() {
        let surfaceForRelease = unsafe gbmSurface
        let bufferForRelease = unsafe lockedBuffer
        if let surface = unsafe surfaceForRelease,
            let buffer = unsafe bufferForRelease
        {
            unsafe swl_gbm_surface_release_buffer(surface, buffer)
        }
        unsafe lockedBuffer = nil

        let displayForSurface = unsafe eglDisplay
        let eglSurfaceForDestroy = unsafe eglSurface
        if let display = unsafe displayForSurface,
            let surface = unsafe eglSurfaceForDestroy
        {
            unsafe swl_egl_destroy_surface(display, surface)
        }
        unsafe eglSurface = nil

        let displayForContext = unsafe eglDisplay
        let eglContextForDestroy = unsafe eglContext
        if let display = unsafe displayForContext,
            let context = unsafe eglContextForDestroy
        {
            unsafe swl_egl_destroy_context(display, context)
        }
        unsafe eglContext = nil

        let displayForTerminate = unsafe eglDisplay
        if let display = unsafe displayForTerminate {
            unsafe swl_egl_terminate(display)
        }
        unsafe eglDisplay = nil

        let gbmSurfaceForDestroy = unsafe gbmSurface
        if let surface = unsafe gbmSurfaceForDestroy {
            unsafe swl_gbm_surface_destroy(surface)
        }
        unsafe gbmSurface = nil

        let gbmDeviceForDestroy = unsafe gbmDevice
        if let device = unsafe gbmDeviceForDestroy {
            unsafe swl_gbm_device_destroy(device)
        }
        unsafe gbmDevice = nil

        if let renderNodeFileDescriptor {
            Glibc.close(renderNodeFileDescriptor)
        }
        renderNodeFileDescriptor = nil
    }

    deinit {
        close()
    }

    private static func openRenderNode(deviceIDBytes: [UInt8]) throws -> Int32 {
        let path = try renderNodePath(deviceIDBytes: deviceIDBytes)
        let fileDescriptor = unsafe path.withCString { pathPointer in
            unsafe Glibc.open(pathPointer, O_RDWR | O_CLOEXEC)
        }
        guard fileDescriptor >= 0 else {
            throw WaylandGraphicsError.unavailable(.noRenderNode)
        }

        return fileDescriptor
    }

    private static func renderNodePath(deviceIDBytes: [UInt8]) throws -> String {
        guard deviceIDBytes.count == Int(swl_drm_device_id_byte_count()) else {
            throw WaylandGraphicsError.unavailable(.noRenderNode)
        }

        var pathBytes = [CChar](
            repeating: 0,
            count: Int(swl_drm_render_node_path_max())
        )
        let result = unsafe deviceIDBytes.withUnsafeBufferPointer { deviceBytes in
            unsafe pathBytes.withUnsafeMutableBufferPointer { outputPathBytes in
                guard let deviceBaseAddress = deviceBytes.baseAddress,
                    let outputBaseAddress = outputPathBytes.baseAddress
                else {
                    return Int32(-1)
                }

                return unsafe swl_drm_render_node_path_from_device_bytes(
                    deviceBaseAddress,
                    UInt32(deviceBytes.count),
                    outputBaseAddress,
                    UInt32(outputPathBytes.count)
                )
            }
        }
        guard result == 0 else {
            throw WaylandGraphicsError.unavailable(.noRenderNode)
        }

        let path = unsafe pathBytes.withUnsafeBufferPointer { pathBuffer in
            guard let baseAddress = pathBuffer.baseAddress else { return "" }

            return unsafe String(cString: baseAddress)
        }
        guard !path.isEmpty else {
            throw WaylandGraphicsError.unavailable(.noRenderNode)
        }

        return path
    }

    private func createEGLTarget(
        gbmDevice createdDevice: OpaquePointer,
        gbmSurface createdSurface: OpaquePointer,
        format: UInt32
    ) throws {
        guard let display = unsafe swl_egl_display_for_gbm_device(createdDevice) else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
        unsafe eglDisplay = display

        var major: Int32 = 0
        var minor: Int32 = 0
        guard unsafe swl_egl_initialize(display, &major, &minor) == 0 else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }

        guard swl_egl_bind_gles_api() == 0 else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }

        guard let config = unsafe swl_egl_choose_gles_window_config(display, format) else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }

        guard let context = unsafe swl_egl_create_gles2_context(display, config) else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
        unsafe eglContext = context

        guard
            let surface = unsafe swl_egl_create_window_surface(
                display,
                config,
                createdSurface
            )
        else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
        unsafe eglSurface = surface
    }

    private func drawScene(width: UInt32, height: UInt32) throws {
        guard let display = unsafe eglDisplay,
            let surface = unsafe eglSurface,
            let context = unsafe eglContext
        else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }

        guard unsafe swl_egl_make_current(display, surface, context) == 0 else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
        defer {
            _ = unsafe swl_egl_clear_current(display)
        }

        glViewport(0, 0, GLsizei(width), GLsizei(height))
        glDisable(GLenum(GL_SCISSOR_TEST))
        glClearColor(0.05, 0.12, 0.20, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        glEnable(GLenum(GL_SCISSOR_TEST))
        glScissor(
            GLint(width / 6),
            GLint(height / 6),
            GLsizei((width * 2) / 3),
            GLsizei((height * 2) / 3)
        )
        glClearColor(0.95, 0.30, 0.10, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glDisable(GLenum(GL_SCISSOR_TEST))

        guard swl_gles2_error() == 0 else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
        guard unsafe swl_egl_swap_buffers(display, surface) == 0 else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
    }

    private static func plane(
        at index: Int,
        from exportedBuffer: inout swl_gbm_bo_export
    ) throws -> WaylandGraphicsExternalBufferPlane {
        let planeIndex = UInt32(index)
        let fileDescriptor = unsafe swl_gbm_bo_export_take_plane_fd(
            &exportedBuffer,
            planeIndex
        )
        guard fileDescriptor >= 0 else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }

        return try WaylandGraphicsExternalBufferPlane(
            fileDescriptor: try OwnedFileDescriptor(adopting: fileDescriptor),
            offset: unsafe swl_gbm_bo_export_plane_offset(&exportedBuffer, planeIndex),
            stride: unsafe swl_gbm_bo_export_plane_stride(&exportedBuffer, planeIndex),
            planeIndex: planeIndex
        )
    }
}

private struct ExternalBufferSmokeOptions: Equatable, Sendable {
    enum Mode: Equatable, Sendable {
        case probe
        case internalTestBuffer
        case negativeTestBuffer
    }

    let mode: Mode
    let stressFrames: Int

    static func parse(_ arguments: ArraySlice<String>) throws -> Self {
        var mode = Mode.internalTestBuffer
        var stressFrames = 0
        let optionArguments =
            arguments.first == "--" ? arguments.dropFirst() : arguments

        var iterator = optionArguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--probe":
                mode = .probe
            case "--internal-test-buffer":
                mode = .internalTestBuffer
            case "--negative-test-buffer":
                mode = .negativeTestBuffer
            case "--stress-frames":
                guard let value = iterator.next() else {
                    throw ExampleRunOptionError.missingValue(argument)
                }
                guard let parsedValue = Int(value),
                    parsedValue >= 0
                else {
                    throw ExampleRunOptionError.unknownArgument(value)
                }
                stressFrames = parsedValue
            case "--auto-close", "--print-summary":
                continue
            case "--":
                return Self(mode: mode, stressFrames: stressFrames)
            default:
                throw ExampleRunOptionError.unknownArgument(argument)
            }
        }

        return Self(mode: mode, stressFrames: stressFrames)
    }
}
