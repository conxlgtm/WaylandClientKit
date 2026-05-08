package enum SmokeArgumentError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownArgument(String)
    case missingValue(String)
    case invalidValue(argument: String, value: String)
    case unsupportedEndOfOptionsMarker

    package var description: String {
        switch self {
        case .unknownArgument(let argument):
            "unknown argument: \(argument)"
        case .missingValue(let argument):
            "missing value for \(argument)"
        case .invalidValue(let argument, let value):
            "invalid value for \(argument): \(value)"
        case .unsupportedEndOfOptionsMarker:
            "-- is not supported because swift-wayland-smoke has no positional arguments"
        }
    }
}

package enum SmokeArguments {
    package static let usage = """
        Usage: swift-wayland-smoke [options]

        Options:
          --timeout-milliseconds <value>      Configure wait timeout. Default: 5000.
          --post-commit-pump-milliseconds <value>
                                             Event pump after first commit. Default: 16.
          -h, --help                         Show this help.
        """

    package static func parse(_ arguments: [String]) throws -> SmokeCommand {
        var timeout = SmokeMilliseconds.defaultTimeout
        var postCommitPump = SmokeMilliseconds.defaultPostCommitPump
        var index = arguments.startIndex

        while index < arguments.endIndex {
            let argument = arguments[index]

            switch argument {
            case "-h", "--help":
                return .help
            case "--":
                throw SmokeArgumentError.unsupportedEndOfOptionsMarker
            case "--timeout-milliseconds":
                timeout = try readMilliseconds(
                    after: argument,
                    in: arguments,
                    index: &index,
                    field: .timeoutMilliseconds
                )
            case "--post-commit-pump-milliseconds":
                postCommitPump = try readMilliseconds(
                    after: argument,
                    in: arguments,
                    index: &index,
                    field: .postCommitPumpMilliseconds
                )
            default:
                throw SmokeArgumentError.unknownArgument(argument)
            }

            arguments.formIndex(after: &index)
        }

        return .run(
            SmokeConfiguration(
                timeout: timeout,
                postCommitPump: postCommitPump
            )
        )
    }

    private static func readMilliseconds(
        after argument: String,
        in arguments: [String],
        index: inout Int,
        field: SmokeConfigurationField
    ) throws -> SmokeMilliseconds {
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
        do {
            return try SmokeMilliseconds(parsed, field: field)
        } catch {
            throw SmokeArgumentError.invalidValue(argument: argument, value: rawValue)
        }
    }
}
