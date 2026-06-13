import Foundation

public struct ToolError: Error, CustomStringConvertible, Equatable {
    public let message: String
    public let exitCode: Int32

    public init(_ message: String, exitCode: Int32 = 1) {
        self.message = message
        self.exitCode = exitCode
    }

    public var description: String {
        message
    }
}

public enum ToolExitCode {
    public static let success: Int32 = 0
    public static let failure: Int32 = 1
    public static let usage: Int32 = 2
    public static let data: Int32 = 3
    public static let environment: Int32 = 4
    public static let process: Int32 = 5
}
