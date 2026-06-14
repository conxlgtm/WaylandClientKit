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
                try await submitInternalTestBuffer(backing: backing)
            }

            try await backing.close()
            log("cleanup: pass")
        }
    }

    private static func submitInternalTestBuffer(
        backing: WaylandGraphicsWindowBacking
    ) async throws {
        log("mode: negative-cleanup")
        log("test buffer: pipe-fd-not-dmabuf")
        let lease = try await backing.nextFrame()
        do {
            let result = try await lease.submitExternalBuffer(
                try externalDescriptor(size: lease.size)
            )
            log("import: active")
            log("submit: active")
            log("release: \(status(result.runtimePath.bufferLifecycle))")
            log(
                "fallback reason: \(result.runtimePath.fallback.map(String.init(describing:)) ?? "none")"
            )
            log("failure: none")
        } catch {
            log("import: failed(expected-cleanup: \(error))")
            log("submit: skipped(import-failed)")
            log("release: not observed")
            log("fallback reason: none")
            log("failure: expected-negative-test(\(error))")
        }
    }

    private static func externalDescriptor(
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

private struct ExternalBufferSmokeOptions: Equatable, Sendable {
    enum Mode: Equatable, Sendable {
        case probe
        case internalTestBuffer
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
