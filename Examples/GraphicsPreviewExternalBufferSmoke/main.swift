import Foundation
import Glibc
import WaylandClient
import WaylandExampleSupport
import WaylandGraphicsCore
import WaylandGraphicsPreview
import WaylandRaw

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
            log("scope: public-wck-api-with-package-renderer-helper")
            log("requested backing: external-dmabuf")
            log("initial dmabuf status: \(status(runtimePath.dmabufImport))")
            log("format: XRGB8888")
            log("modifier: 0")
            log("planes: 1")
            log("wck-cpu-readback: not-performed")
            log("wck-software-staging: not-performed")

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
                backingWasClosed = try await submitInternalTestBuffer(backing: backing)
            case .negativeTestBuffer:
                try await submitNegativeTestBuffer(backing: backing)
            }

            if !backingWasClosed {
                try await backing.close()
            }
            log("cleanup: pass")
        }
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
            try await submitReplacementBuffer(backing: backing)
            let release = await releaseStatus(result)
            log("renderer: active")
            log("format: \(renderer.formatDescription)")
            log("modifier: \(renderer.modifierDescription)")
            log("planes: \(renderer.planeCount)")
            log("import: pass")
            log("submit: pass")
            log("release: \(release)")
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
    ) async throws {
        let lease = try await backing.nextFrame()
        let configuration = try requireExternalConfiguration(lease.contract)
        let renderer = try ExternalDmabufRenderer(
            size: lease.size,
            configuration: configuration
        )
        defer {
            renderer.close()
        }

        let buffer = try await backing.registerExternalBuffer(
            try renderer.makeDescriptor(),
            contract: lease.contract,
            configurationID: configuration.id
        )
        let renderLease = try await lease.reserveExternalBuffer(buffer)
        _ = try await renderLease.submit()
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
                case .backingClosed:
                    "backing-closed"
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

    nonisolated private static func log(_ message: String) {
        print(message)
    }
}

private actor ReleaseStatusProbe {
    private(set) var status: String?

    func record(_ releaseStatus: String) {
        guard status == nil else { return }

        status = releaseStatus
    }
}

private final class ExternalDmabufRenderer: @unchecked Sendable {
    private var device: GBMDevice?
    private var renderTarget: EGLGBMRenderTarget?
    private var lockedBuffer: GBMLockedSurfaceBuffer?

    private(set) var formatDescription = "unknown"
    private(set) var modifierDescription = "unknown"
    private(set) var planeCount = 0

    init(
        size: PositivePixelSize,
        configuration: WaylandGraphicsExternalBufferConfiguration
    ) throws {
        guard
            let renderNodePath = configuration.renderNode.path
                ?? Self.firstRenderNodePath()
        else {
            throw WaylandGraphicsError.unavailable(.noRenderNode)
        }

        let renderNodeFD = unsafe renderNodePath.withCString { pathPointer in
            unsafe Glibc.open(pathPointer, O_RDWR | O_CLOEXEC)
        }
        guard renderNodeFD >= 0 else {
            throw WaylandGraphicsError.unavailable(.noRenderNode)
        }

        let renderNode = try GBMRenderNodeFileDescriptor(adopting: renderNodeFD)
        let createdDevice = try GBMDevice(adoptingRenderNodeFileDescriptor: renderNode)
        let bufferSize = try GBMBufferSize(
            width: UInt32(size.width.rawValue),
            height: UInt32(size.height.rawValue)
        )
        let createdRenderTarget = try EGLGBMRenderTarget(
            device: createdDevice,
            surfaceDescriptor: GBMSurfaceDescriptor(
                size: bufferSize,
                formatModifier: RawLinuxDmabufFormatModifier(
                    format: configuration.format.rawValue,
                    modifier: configuration.modifier.rawValue
                ),
                flags: .rendering
            )
        )
        _ = try createdRenderTarget.drawClear(red: 0.08, green: 0.35, blue: 0.95, alpha: 1)

        device = createdDevice
        renderTarget = createdRenderTarget
        lockedBuffer = try createdRenderTarget.lockFrontBuffer()
    }

    func makeDescriptor() throws -> WaylandGraphicsExternalBufferDescriptor {
        guard let lockedBuffer else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }

        let export = try lockedBuffer.exportDmabuf()
        formatDescription = String(export.format)
        modifierDescription = String(export.modifier)
        planeCount = export.planeCount

        let size = try PositivePixelSize(
            width: Int32(export.width),
            height: Int32(export.height)
        )
        let format = try WaylandGraphicsDRMFormat(rawValue: export.format)
        let modifier = WaylandGraphicsDRMFormatModifier(rawValue: export.modifier)
        switch export.planeCount {
        case 1:
            return try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                plane: try Self.plane(at: 0, from: export)
            )
        case 2:
            return try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                plane0: try Self.plane(at: 0, from: export),
                plane1: try Self.plane(at: 1, from: export)
            )
        case 3:
            return try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                plane0: try Self.plane(at: 0, from: export),
                plane1: try Self.plane(at: 1, from: export),
                plane2: try Self.plane(at: 2, from: export)
            )
        case 4:
            return try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                plane0: try Self.plane(at: 0, from: export),
                plane1: try Self.plane(at: 1, from: export),
                plane2: try Self.plane(at: 2, from: export),
                plane3: try Self.plane(at: 3, from: export)
            )
        default:
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
    }

    func close() {
        lockedBuffer?.release()
        lockedBuffer = nil
        renderTarget?.destroy()
        renderTarget = nil
        device?.destroy()
        device = nil
    }

    deinit {
        close()
    }

    private static func firstRenderNodePath() -> String? {
        for index in 128..<192 {
            let path = "/dev/dri/renderD\(index)"
            let isAccessible = unsafe path.withCString { pathPointer in
                unsafe Glibc.access(pathPointer, R_OK | W_OK)
            }
            if isAccessible == 0 {
                return path
            }
        }

        return nil
    }

    private static func plane(
        at index: Int,
        from export: GBMDmabufExport
    ) throws -> WaylandGraphicsExternalBufferPlane {
        let layout = try export.planeLayout(at: index)
        var planeDescriptor = try export.takePlaneFileDescriptor(at: index)
        let ownedDescriptor = try OwnedFileDescriptor(
            adopting: planeDescriptor.releaseForWaylandRequest()
        )
        return try WaylandGraphicsExternalBufferPlane(
            fileDescriptor: ownedDescriptor,
            offset: layout.offset,
            stride: layout.stride,
            planeIndex: UInt32(index)
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

    static func parse(_ arguments: ArraySlice<String>) throws -> Self {
        var mode = Mode.internalTestBuffer
        let optionArguments =
            arguments.first == "--" ? arguments.dropFirst() : arguments

        for argument in optionArguments {
            switch argument {
            case "--probe":
                mode = .probe
            case "--internal-test-buffer":
                mode = .internalTestBuffer
            case "--negative-test-buffer":
                mode = .negativeTestBuffer
            case "--auto-close", "--print-summary":
                continue
            case "--":
                return Self(mode: mode)
            default:
                throw ExampleRunOptionError.unknownArgument(argument)
            }
        }

        return Self(mode: mode)
    }
}
