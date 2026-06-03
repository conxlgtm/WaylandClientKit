import Foundation
import PackagePlugin

@main
struct SwlCheckPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments _: [String]) async throws {
        try run(context: context, "ci", "check")
    }
}

func run(context: PluginContext, _ arguments: String...) throws {
    let scratchPath = context.pluginWorkDirectoryURL
        .appendingPathComponent("swift-run", isDirectory: true)
        .path
    let nestedScratchPath = context.pluginWorkDirectoryURL
        .appendingPathComponent("nested-swiftpm", isDirectory: true)
        .path
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "run", "--scratch-path", scratchPath, "swl"] + arguments
    var environment = ProcessInfo.processInfo.environment
    environment["SWIFT_WAYLAND_SWIFTPM_SCRATCH"] = nestedScratchPath
    process.environment = environment
    try process.run()
    process.waitUntilExit()
    if process.terminationReason == .exit,
        process.terminationStatus == 0
    {
        return
    }
    throw PluginError.commandFailed(process.terminationStatus)
}

enum PluginError: Error {
    case commandFailed(Int32)
}
