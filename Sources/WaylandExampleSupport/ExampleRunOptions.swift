public enum ExampleRunOptionError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownArgument(String)
    case missingValue(String)
    case invalidDuration(String)

    public var description: String {
        switch self {
        case .unknownArgument(let argument):
            "unknown argument: \(argument)"
        case .missingValue(let argument):
            "missing value for \(argument)"
        case .invalidDuration(let value):
            "invalid duration seconds: \(value)"
        }
    }
}

public struct ExampleRunOptions: Equatable, Sendable {
    public let durationSeconds: Int?
    public let autoClose: Bool
    public let printSummary: Bool

    public init(
        durationSeconds runDurationSeconds: Int? = nil,
        autoClose runAutoClose: Bool = false,
        printSummary runPrintSummary: Bool = false
    ) {
        durationSeconds = runDurationSeconds
        autoClose = runAutoClose
        printSummary = runPrintSummary
    }

    public var autoCloseSeconds: Int? {
        if let durationSeconds {
            return durationSeconds
        }

        return autoClose ? 3 : nil
    }

    public static func parse(_ arguments: ArraySlice<String>) throws -> ExampleRunOptions {
        var durationSeconds: Int?
        var autoClose = false
        var printSummary = false
        var index = arguments.startIndex

        parseLoop: while index < arguments.endIndex {
            let argument = arguments[index]
            switch argument {
            case "--duration-seconds":
                let valueIndex = arguments.index(after: index)
                guard valueIndex < arguments.endIndex else {
                    throw ExampleRunOptionError.missingValue(argument)
                }
                let rawValue = arguments[valueIndex]
                guard let value = Int(rawValue), value > 0 else {
                    throw ExampleRunOptionError.invalidDuration(rawValue)
                }
                durationSeconds = value
                index = valueIndex
            case "--auto-close":
                autoClose = true
            case "--print-summary":
                printSummary = true
            case "--":
                break parseLoop
            default:
                throw ExampleRunOptionError.unknownArgument(argument)
            }

            arguments.formIndex(after: &index)
        }

        return ExampleRunOptions(
            durationSeconds: durationSeconds,
            autoClose: autoClose,
            printSummary: printSummary
        )
    }
}
