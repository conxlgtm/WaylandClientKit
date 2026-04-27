public enum SmokeArgumentError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownArgument(String)
    case missingValue(String)
    case invalidValue(argument: String, value: String)

    public var description: String {
        switch self {
        case .unknownArgument(let argument):
            "unknown argument: \(argument)"
        case .missingValue(let argument):
            "missing value for \(argument)"
        case .invalidValue(let argument, let value):
            "invalid value for \(argument): \(value)"
        }
    }
}

public enum SmokeArguments {
    public static let usage = """
        Usage: swift-wayland-smoke [options]

        Options:
          --timeout-milliseconds <value>      Configure wait timeout. Default: 5000.
          --post-commit-pump-milliseconds <value>
                                             Event pump after first commit. Default: 16.
          -h, --help                         Show this help.
        """

    public static func parse(_ arguments: [String]) throws -> SmokeCommand {
        var configuration = SmokeConfiguration()
        var index = arguments.startIndex

        while index < arguments.endIndex {
            let argument = arguments[index]

            switch argument {
            case "-h", "--help":
                return .help
            case "--":
                break
            case "--timeout-milliseconds":
                configuration.timeoutMilliseconds = try readPositiveInt32(
                    after: argument,
                    in: arguments,
                    index: &index
                )
            case "--post-commit-pump-milliseconds":
                configuration.postCommitPumpMilliseconds = try readPositiveInt32(
                    after: argument,
                    in: arguments,
                    index: &index
                )
            default:
                throw SmokeArgumentError.unknownArgument(argument)
            }

            arguments.formIndex(after: &index)
        }

        return .run(configuration)
    }

    private static func readPositiveInt32(
        after argument: String,
        in arguments: [String],
        index: inout Int
    ) throws -> Int32 {
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            throw SmokeArgumentError.missingValue(argument)
        }

        let rawValue = arguments[valueIndex]
        guard
            let parsed = Int32(rawValue),
            parsed > 0
        else {
            throw SmokeArgumentError.invalidValue(argument: argument, value: rawValue)
        }

        index = valueIndex
        return parsed
    }
}
