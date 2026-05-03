public struct InputDiagnostic: Equatable, Sendable {
    public let payload: InputDiagnosticPayload

    public init(_ diagnosticPayload: InputDiagnosticPayload) {
        payload = diagnosticPayload
    }

    public var operation: InputDiagnosticOperation {
        payload.operation
    }

    public var message: String {
        payload.description
    }
}

public enum InputDiagnosticPayload: Equatable, Sendable {
    case keymap(KeymapDiagnostic)
    case listener(InputListenerDiagnostic)
    case inputPipelineOverflow(InputPipelineOverflow)
    case cursor(CursorDiagnostic)

    public var operation: InputDiagnosticOperation {
        switch self {
        case .keymap:
            .keyboardKeymap
        case .listener(let diagnostic):
            .listener(diagnostic.listener)
        case .inputPipelineOverflow(let overflow):
            .inputPipelineOverflow(overflow)
        case .cursor(let diagnostic):
            .cursor(diagnostic.operation)
        }
    }
}

extension InputDiagnosticPayload: CustomStringConvertible {
    public var description: String {
        switch self {
        case .keymap(let diagnostic):
            diagnostic.description
        case .listener(let diagnostic):
            diagnostic.description
        case .inputPipelineOverflow(let overflow):
            "\(overflow.stage.description) exceeded capacity \(overflow.capacity)"
        case .cursor(let diagnostic):
            diagnostic.description
        }
    }
}

public enum KeymapDiagnostic: Equatable, Sendable, CustomStringConvertible {
    case readFailed(KeymapReadFailure)

    public var description: String {
        switch self {
        case .readFailed(let failure):
            failure.description
        }
    }
}

public enum KeymapReadFailure: Equatable, Sendable, CustomStringConvertible {
    case unsupportedFormat(format: KeyboardKeymapFormat, advertisedSize: UInt32)
    case invalidFileDescriptor(Int32)
    case invalidSizeLimit(maxSize: UInt32, hardMaximumSize: UInt32)
    case emptyXKBV1Payload(size: UInt32)
    case tooLarge(size: UInt32, maxSize: UInt32)
    case tooLargeForProtocolSize(Int)
    case fdTooSmall(size: UInt32, actualSize: Int64)
    case missingNULTerminator(size: UInt32)
    case system(WaylandSystemError)

    public var description: String {
        switch self {
        case .unsupportedFormat(let format, let advertisedSize):
            "unsupported keymap format \(format.rawValue) with advertised size \(advertisedSize)"
        case .invalidFileDescriptor(let descriptor):
            "invalid keymap file descriptor \(descriptor)"
        case .invalidSizeLimit(let maxSize, let hardMaximumSize):
            "invalid keymap size limit \(maxSize); maximum supported limit is \(hardMaximumSize)"
        case .emptyXKBV1Payload(let size):
            "empty xkb_v1 keymap payload with advertised size \(size)"
        case .tooLarge(let size, let maxSize):
            "keymap size \(size) exceeds configured maximum \(maxSize)"
        case .tooLargeForProtocolSize(let byteCount):
            "keymap byte count \(byteCount) exceeds UInt32"
        case .fdTooSmall(let size, let actualSize):
            "keymap fd contains \(actualSize) bytes, fewer than advertised size \(size)"
        case .missingNULTerminator(let size):
            "xkb_v1 keymap of size \(size) is not NUL-terminated"
        case .system(let error):
            "system error during keymap read: \(error.description)"
        }
    }
}

public struct InputListenerDiagnostic: Equatable, Sendable, CustomStringConvertible {
    public let listener: String
    public let message: String

    public init(listener listenerName: String, message diagnosticMessage: String) {
        listener = listenerName
        message = diagnosticMessage
    }

    public var description: String {
        message
    }
}

public enum CursorDiagnosticOperation: Equatable, Sendable {
    case missingCursor
    case automaticPointerEnter
}

public enum CursorDiagnostic: Equatable, Sendable, CustomStringConvertible {
    case missingCursor(name: String)
    case automaticPointerEnterFailed(String)

    public var operation: CursorDiagnosticOperation {
        switch self {
        case .missingCursor:
            .missingCursor
        case .automaticPointerEnterFailed:
            .automaticPointerEnter
        }
    }

    public var description: String {
        switch self {
        case .missingCursor(let name):
            "cursor \(name) is unavailable"
        case .automaticPointerEnterFailed(let message):
            message
        }
    }
}

public enum InputDiagnosticOperation: Equatable, Sendable {
    case keyboardKeymap
    case listener(String)
    case inputPipelineOverflow(InputPipelineOverflow)
    case cursor(CursorDiagnosticOperation)
}
