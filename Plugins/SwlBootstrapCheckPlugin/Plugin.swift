import Foundation
import PackagePlugin

@main
struct SwlBootstrapCheckPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try run(context: context, "bootstrap", "check")
    }
}

func run(context: PluginContext, _ arguments: String...) throws {
    let scratchPath = context.pluginWorkDirectoryURL
        .appendingPathComponent("swift-run", isDirectory: true)
        .path
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "run", "--scratch-path", scratchPath, "swl"] + arguments
    try process.run()
    process.waitUntilExit()
    if process.terminationReason == .exit && process.terminationStatus == 0 {
        return
    }
    throw PluginError.commandFailed(process.terminationStatus)
}

enum PluginError: Error {
    case commandFailed(Int32)
}
