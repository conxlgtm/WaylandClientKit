import Foundation

public struct Diagnostics: Sendable {
    public var isVerbose: Bool
    public var output: @Sendable (String) -> Void
    public var errorOutput: @Sendable (String) -> Void

    public init(
        isVerbose: Bool = false,
        output: @escaping @Sendable (String) -> Void = Diagnostics.standardOutput,
        errorOutput: @escaping @Sendable (String) -> Void = { line in
            guard let data = (line + "\n").data(using: .utf8) else { return }
            FileHandle.standardError.write(data)
        }
    ) {
        self.isVerbose = isVerbose
        self.output = output
        self.errorOutput = errorOutput
    }

    public func info(_ message: String) {
        output(message)
    }

    public func success(_ message: String) {
        output("ok: \(message)")
    }

    public func warning(_ message: String) {
        errorOutput("warning: \(message)")
    }

    public func error(_ message: String) {
        errorOutput("error: \(message)")
    }

    public func verbose(_ message: String) {
        guard isVerbose else { return }
        output("verbose: \(message)")
    }

    @usableFromInline
    static func standardOutput(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }
}
