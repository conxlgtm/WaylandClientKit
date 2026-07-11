public enum ClientError: Error, Equatable, Sendable, CustomStringConvertible {
    case windowCreationFailed(WindowCreationFailure)
    case invalidWindowState(InvalidWindowState)
    case display(DisplayOperationError)
    case invalidWindowConfiguration(WindowConfigurationError)
    case domainValue(DomainValueError)
    case cursor(PointerCursorError)
    case window(WindowID, WindowError)

    public var description: String {
        switch self {
        case .windowCreationFailed(let detail):
            "Window creation failed: \(detail)"
        case .invalidWindowState(let detail):
            "Invalid window state: \(detail)"
        case .display(let error):
            "Display failed: \(error.description)"
        case .invalidWindowConfiguration(let error):
            "Invalid window configuration: \(error.description)"
        case .domainValue(let error):
            "Invalid domain value: \(error.description)"
        case .cursor(let error):
            "Cursor failed: \(error.description)"
        case .window(let windowID, let error):
            "Window \(windowID) failed: \(error.description)"
        }
    }
}

public enum WindowCreationFailure: Equatable, Sendable, CustomStringConvertible {
    case requiredGlobalsNotBound
    case clockGetTimeFailed(errno: Int32)
    case message(String)

    public var description: String {
        switch self {
        case .requiredGlobalsNotBound:
            "required globals are not bound"
        case .clockGetTimeFailed(let errno):
            "clock_gettime failed with errno \(errno)"
        case .message(let message):
            message
        }
    }
}

public enum InvalidWindowState: Equatable, Sendable, CustomStringConvertible {
    case unknownPopupGrabSeat(SeatID)
    case unknownWindowInteractionSeat(SeatID)
    case unknownWindowFullscreenOutput(OutputID)
    case unexpectedPopupConfigureError(String)
    case softwareFrameLayout(SoftwareFrameLayoutError)
    case message(String)

    public var description: String {
        switch self {
        case .unknownPopupGrabSeat(let seatID):
            "unknown popup grab seat \(seatID)"
        case .unknownWindowInteractionSeat(let seatID):
            "unknown window interaction seat \(seatID)"
        case .unknownWindowFullscreenOutput(let outputID):
            "unknown window fullscreen output \(outputID)"
        case .unexpectedPopupConfigureError(let message):
            "unexpected popup configure error: \(message)"
        case .softwareFrameLayout(let error):
            error.description
        case .message(let message):
            message
        }
    }
}

public enum SoftwareFrameLayoutError: Equatable, Sendable, CustomStringConvertible {
    case nonPositiveDimensions(width: Int32, height: Int32)
    case minimumStrideOverflow(width: Int32)
    case strideTooSmall(width: Int32, stride: Int32, minimumStride: Int)
    case requiredByteCountOverflow(stride: Int32, height: Int32)
    case storageTooSmall(requiredByteCount: Int, actualByteCount: Int)

    public var description: String {
        switch self {
        case .nonPositiveDimensions(let width, let height):
            "software frame dimensions must be greater than zero, got \(width)x\(height)"
        case .minimumStrideOverflow(let width):
            "software frame minimum stride overflowed for width \(width)"
        case .strideTooSmall(let width, let stride, let minimumStride):
            "software frame stride \(stride) is too small for width \(width); "
                + "minimum stride is \(minimumStride)"
        case .requiredByteCountOverflow(let stride, let height):
            "software frame byte count overflowed for stride \(stride), height \(height)"
        case .storageTooSmall(let requiredByteCount, let actualByteCount):
            "software frame storage has \(actualByteCount) bytes; "
                + "requires \(requiredByteCount)"
        }
    }
}
