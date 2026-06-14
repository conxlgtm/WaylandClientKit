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
                    fallbackPolicy: .requireGPU,
                    backingPreference: .managedGPU
                )
            )
            let runtimePath = try await backing.runtimePath
            log("feature: external-gpu-buffer")
            log("requested backing: external-dmabuf")
            log("dmabuf: \(status(runtimePath.dmabufImport))")
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
        let primedSize = try await primeSurfaceGeometry(backing: backing)
        log("primed frame size: \(primedSize.width.rawValue)x\(primedSize.height.rawValue)")
        let lease = try await backing.nextFrame()
        let renderer: ExternalDmabufRenderer
        do {
            renderer = try ExternalDmabufRenderer(size: lease.size)
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
            let result = try await lease.submitExternalBuffer(try renderer.makeDescriptor())
            log("renderer: active")
            log("format: \(renderer.formatDescription)")
            log("modifier: \(renderer.modifierDescription)")
            log("planes: \(renderer.planeCount)")
            log("import: active")
            log("submit: active")
            log("release: \(status(result.runtimePath.bufferLifecycle))")
            log("release/reuse: tracked-by-wayland-client-kit")
            log(
                "fallback reason: \(result.runtimePath.fallback.map(String.init(describing:)) ?? "none")"
            )
            log("failure: none")
            try await backing.close()
            return true
        } catch {
            log("renderer: active")
            log("format: \(renderer.formatDescription)")
            log("modifier: \(renderer.modifierDescription)")
            log("planes: \(renderer.planeCount)")
            log("import: failed(\(error))")
            log("submit: skipped(import-failed)")
            log("release: not observed")
            log("fallback reason: none")
            log("failure: \(error)")
            return false
        }
    }

    private static func primeSurfaceGeometry(
        backing: WaylandGraphicsWindowBacking
    ) async throws -> PositivePixelSize {
        let lease = try await backing.nextFrame()
        let result = try await lease.submitSoftware { frame in
            drawPrimeFrame(frame)
        }
        return result.size
    }

    private static func drawPrimeFrame(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { _, pixels in
            for index in 0..<pixels.count {
                unsafe pixels[unchecked: index] = 0x0010_1820
            }
        }
    }

    private static func submitNegativeTestBuffer(
        backing: WaylandGraphicsWindowBacking
    ) async throws {
        log("mode: negative-cleanup")
        log("test buffer: pipe-fd-not-dmabuf")
        let lease = try await backing.nextFrame()
        do {
            _ = try await lease.submitExternalBuffer(
                try pipeBackedExternalDescriptor(size: lease.size)
            )
            log("import: active(unexpected)")
            log("submit: active(unexpected)")
            log("release: active(unexpected)")
            log("fallback reason: none")
            log("failure: unexpected-pipe-fd-import-success")
        } catch {
            log("import: failed(expected-cleanup: \(error))")
            log("submit: skipped(import-failed)")
            log("release: not observed")
            log("fallback reason: none")
            log("failure: expected-negative-test(\(error))")
        }
    }

    private static func pipeBackedExternalDescriptor(
        size: PositivePixelSize
    ) throws -> WaylandGraphicsExternalBufferDescriptor {
        let stride = UInt32(size.width.rawValue) * 4
        let plane = try WaylandGraphicsExternalBufferPlane(
            fd: try pipeReadDescriptor(),
            offset: 0,
            stride: stride,
            planeIndex: 0
        )
        return try WaylandGraphicsExternalBufferDescriptor(
            size: size,
            format: WaylandGraphicsDRMFormat(rawValue: drmFormatXRGB8888),
            modifier: WaylandGraphicsDRMFormatModifier(rawValue: 0),
            planes: .one(plane)
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

    nonisolated private static func log(_ message: String) {
        print(message)
    }
}

private final class ExternalDmabufRenderer: @unchecked Sendable {
    private var device: GBMDevice?
    private var renderTarget: EGLGBMRenderTarget?
    private var lockedBuffer: GBMLockedSurfaceBuffer?

    private(set) var formatDescription = "unknown"
    private(set) var modifierDescription = "unknown"
    private(set) var planeCount = 0

    init(size: PositivePixelSize) throws {
        guard let renderNodePath = Self.firstRenderNodePath() else {
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
                    format: GBMDRMFormat.xrgb8888,
                    modifier: GBMDRMModifier.invalid
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
        return try WaylandGraphicsExternalBufferDescriptor(
            size: size,
            format: format,
            modifier: modifier,
            planes: try Self.planes(from: export)
        )
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

    private static func planes(
        from export: GBMDmabufExport
    ) throws -> WaylandGraphicsExternalBufferPlanes {
        switch export.planeCount {
        case 1:
            return .one(try plane(at: 0, from: export))
        case 2:
            return .two(
                try plane(at: 0, from: export),
                try plane(at: 1, from: export)
            )
        case 3:
            return .three(
                try plane(at: 0, from: export),
                try plane(at: 1, from: export),
                try plane(at: 2, from: export)
            )
        case 4:
            return .four(
                try plane(at: 0, from: export),
                try plane(at: 1, from: export),
                try plane(at: 2, from: export),
                try plane(at: 3, from: export)
            )
        default:
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
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
            fd: ownedDescriptor,
            offset: layout.offset,
            stride: layout.stride,
            planeIndex: layout.index
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
        var parser = ExternalBufferSmokeOptionParser(arguments: arguments)
        return try parser.parse()
    }
}

private struct ExternalBufferSmokeOptionParser {
    private let arguments: ArraySlice<String>
    private var index: ArraySlice<String>.Index
    private var mode = ExternalBufferSmokeOptions.Mode.probe

    init(arguments parserArguments: ArraySlice<String>) {
        arguments = parserArguments
        index = parserArguments.startIndex
    }

    mutating func parse() throws -> ExternalBufferSmokeOptions {
        skipLeadingSwiftPMSeparator()
        while index < arguments.endIndex {
            switch arguments[index] {
            case "--probe":
                mode = .probe
            case "--internal-test-buffer":
                mode = .internalTestBuffer
            case "--negative-test-buffer":
                mode = .negativeTestBuffer
            case "--":
                return ExternalBufferSmokeOptions(mode: mode)
            default:
                throw ExampleRunOptionError.unknownArgument(arguments[index])
            }
            arguments.formIndex(after: &index)
        }

        return ExternalBufferSmokeOptions(mode: mode)
    }

    private mutating func skipLeadingSwiftPMSeparator() {
        guard index == arguments.startIndex, index < arguments.endIndex else {
            return
        }
        if arguments[index] == "--" {
            arguments.formIndex(after: &index)
        }
    }
}
