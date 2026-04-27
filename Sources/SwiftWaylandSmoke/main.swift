import Foundation
import Glibc
import WaylandSmokeSupport

@main
enum SwiftWaylandSmoke {
    static func main() {
        do {
            let command = try SmokeArguments.parse(Array(CommandLine.arguments.dropFirst()))

            switch command {
            case .help:
                StandardIO.writeOutput(SmokeArguments.usage)
            case .run(let configuration):
                let result = try SmokeRunner.run(configuration: configuration)
                StandardIO.writeOutput("swift-wayland-smoke: \(result.description)\n")
            }
        } catch {
            StandardIO.writeError("swift-wayland-smoke: \(error)\n")
            exit(EXIT_FAILURE)
        }
    }
}

private enum StandardIO {
    static func writeOutput(_ message: String) {
        FileHandle.standardOutput.write(Data(message.utf8))
    }

    static func writeError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}
