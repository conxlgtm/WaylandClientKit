import Foundation
import WaylandClient
import WaylandExampleSupport
import WaylandGraphicsPreview

@main
enum GraphicsPreviewExternalBufferSmoke {
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
            case .negativeTestBuffer:
                log("mode: maintainer-negative-only")
                log("import: skipped(use GraphicsPreviewExternalBufferMaintainerSmoke)")
                log("submit: skipped(maintainer-only)")
                log("release: not observed")
                log("fallback reason: none")
                log("failure: none")
            case .maintainerTestBufferRedirect:
                log("mode: maintainer-only")
                log("import: skipped(use GraphicsPreviewExternalBufferMaintainerSmoke)")
                log("submit: skipped(maintainer-only)")
                log("release: not observed")
                log("fallback reason: none")
                log("failure: none")
            }

            try await backing.close()
            log("cleanup: pass")
        }
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
        case negativeTestBuffer
        case maintainerTestBufferRedirect
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
            case "--negative-test-buffer":
                mode = .negativeTestBuffer
            case "--internal-test-buffer":
                mode = .maintainerTestBufferRedirect
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
