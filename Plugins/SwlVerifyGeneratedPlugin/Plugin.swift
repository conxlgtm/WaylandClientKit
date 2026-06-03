import Foundation
import PackagePlugin

@main
struct SwlVerifyGeneratedPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try run("protocols", "verify-generated")
    }
}

func run(_ arguments: String...) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "run", "swl"] + arguments
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
