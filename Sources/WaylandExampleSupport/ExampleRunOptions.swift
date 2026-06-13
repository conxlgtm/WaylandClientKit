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
        var parser = ExampleRunOptionParser(arguments: arguments)
        return try parser.parse()
    }
}

private struct ExampleRunOptionParser {
    private let arguments: ArraySlice<String>
    private var index: ArraySlice<String>.Index
    private var durationSeconds: Int?
    private var autoClose = false
    private var printSummary = false
    private var synchronization: String?
    private var pacing: String?
    private var metadata: String?
    private var contentType: String?
    private var presentationHint: String?

    init(arguments parserArguments: ArraySlice<String>) {
        arguments = parserArguments
        index = parserArguments.startIndex
    }

    mutating func parse() throws -> ExampleRunOptions {
        while index < arguments.endIndex {
            let shouldContinue = try consume(arguments[index])
            if !shouldContinue {
                break
            }
            arguments.formIndex(after: &index)
        }

        return options()
    }

    private mutating func consume(_ argument: String) throws -> Bool {
        switch argument {
        case "--duration-seconds":
            durationSeconds = try durationValue(for: argument)
        case "--auto-close":
            autoClose = true
        case "--print-summary":
            printSummary = true
        case "--sync", "--synchronization":
            synchronization = try optionValue(for: argument)
        case "--pacing":
            pacing = try optionValue(for: argument)
        case "--metadata":
            metadata = try optionValue(for: argument)
        case "--content-type":
            contentType = try optionValue(for: argument)
        case "--presentation-hint":
            presentationHint = try optionValue(for: argument)
        case "--":
            return false
        default:
            throw ExampleRunOptionError.unknownArgument(argument)
        }

        return true
    }

    private mutating func durationValue(for argument: String) throws -> Int {
        let rawValue = try optionValue(for: argument)
        guard let value = Int(rawValue), value > 0 else {
            throw ExampleRunOptionError.invalidDuration(rawValue)
        }

        return value
    }

    private mutating func optionValue(for argument: String) throws -> String {
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            throw ExampleRunOptionError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private func options() -> ExampleRunOptions {
        ExampleRunOptions(
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
}
