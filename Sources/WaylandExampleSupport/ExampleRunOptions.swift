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
    public let synchronization: String?
    public let pacing: String?
    public let metadata: String?
    public let contentType: String?
    public let presentationHint: String?

    public init(
        durationSeconds runDurationSeconds: Int? = nil,
        autoClose runAutoClose: Bool = false,
        printSummary runPrintSummary: Bool = false,
        synchronization runSynchronization: String? = nil,
        pacing runPacing: String? = nil,
        metadata runMetadata: String? = nil,
        contentType runContentType: String? = nil,
        presentationHint runPresentationHint: String? = nil
    ) {
        durationSeconds = runDurationSeconds
        autoClose = runAutoClose
        printSummary = runPrintSummary
        synchronization = runSynchronization
        pacing = runPacing
        metadata = runMetadata
        contentType = runContentType
        presentationHint = runPresentationHint
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
        var synchronization: String?
        var pacing: String?
        var metadata: String?
        var contentType: String?
        var presentationHint: String?
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
            case "--sync", "--synchronization":
                (synchronization, index) = try optionValue(
                    after: index,
                    argument: argument,
                    arguments: arguments
                )
            case "--pacing":
                (pacing, index) = try optionValue(
                    after: index,
                    argument: argument,
                    arguments: arguments
                )
            case "--metadata":
                (metadata, index) = try optionValue(
                    after: index,
                    argument: argument,
                    arguments: arguments
                )
            case "--content-type":
                (contentType, index) = try optionValue(
                    after: index,
                    argument: argument,
                    arguments: arguments
                )
            case "--presentation-hint":
                (presentationHint, index) = try optionValue(
                    after: index,
                    argument: argument,
                    arguments: arguments
                )
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
            printSummary: printSummary,
            synchronization: synchronization,
            pacing: pacing,
            metadata: metadata,
            contentType: contentType,
            presentationHint: presentationHint
        )
    }

    private static func optionValue(
        after index: ArraySlice<String>.Index,
        argument: String,
        arguments: ArraySlice<String>
    ) throws -> (String, ArraySlice<String>.Index) {
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            throw ExampleRunOptionError.missingValue(argument)
        }

        return (arguments[valueIndex], valueIndex)
    }
}
