/// A failure encountered while reading Wayland protocol XML.
public struct WaylandProtocolXMLParserError:
    Error,
    Equatable,
    Sendable,
    CustomStringConvertible
{
    /// The path or label supplied by the caller.
    public let source: String

    /// The one-based source line, when available.
    public let line: Int

    /// The one-based source column, when available.
    public let column: Int

    /// A direct description of the malformed input.
    public let message: String

    /// Creates a parser error.
    public init(
        source errorSource: String, line errorLine: Int, column errorColumn: Int, message: String
    ) {
        source = errorSource
        line = errorLine
        column = errorColumn
        self.message = message
    }

    /// The source location and parser message in diagnostic form.
    public var description: String {
        "\(source):\(line):\(column): \(message)"
    }
}
