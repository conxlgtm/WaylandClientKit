public struct ActivationToken: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ tokenValue: String) throws {
        guard !tokenValue.isEmpty else {
            throw ActivationError.invalidToken
        }

        guard !tokenValue.contains("\0") else {
            throw ActivationError.invalidToken
        }

        value = tokenValue
    }

    package init(unchecked tokenValue: String) {
        precondition(!tokenValue.isEmpty, "activation tokens must not be empty")
        precondition(!tokenValue.contains("\0"), "activation tokens must not contain NUL bytes")
        value = tokenValue
    }

    public var description: String {
        value
    }
}

public struct ActivationAppID: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ appIDValue: String) throws {
        guard !appIDValue.isEmpty, !appIDValue.contains("\0") else {
            throw ActivationError.invalidAppID
        }

        value = appIDValue
    }

    public var description: String {
        value
    }
}

public struct ActivationSerialContext: Equatable, Hashable, Sendable {
    public let seatID: SeatID
    public let serial: InputSerial

    public init(seatID contextSeatID: SeatID, serial contextSerial: InputSerial) {
        seatID = contextSeatID
        serial = contextSerial
    }
}

public struct ActivationTokenRequest: Equatable, Sendable {
    public var appID: ActivationAppID?
    public var window: Window?
    public var serialContext: ActivationSerialContext?

    public init() {
        appID = nil
        window = nil
        serialContext = nil
    }

    public init(
        appID requestAppID: ActivationAppID? = nil,
        window requestWindow: Window? = nil,
        serialContext requestSerialContext: ActivationSerialContext? = nil
    ) {
        appID = requestAppID
        window = requestWindow
        serialContext = requestSerialContext
    }

    public init(
        validatingAppID requestAppID: String?,
        window requestWindow: Window? = nil,
        serialContext requestSerialContext: ActivationSerialContext? = nil
    ) throws {
        appID = try requestAppID.map(ActivationAppID.init)
        window = requestWindow
        serialContext = requestSerialContext
    }
}

package struct ActivationTokenRequestPlan: Equatable, Sendable {
    package let appID: ActivationAppID?
    package let windowID: WindowID?
    package let serialContext: ActivationSerialContext?

    package init(_ request: ActivationTokenRequest) {
        appID = request.appID
        windowID = request.window?.id
        serialContext = request.serialContext
    }
}

public enum ActivationError: Error, Equatable, Sendable, CustomStringConvertible {
    case unavailable
    case foreignWindow(WindowID)
    case unknownWindow(WindowID)
    case closedWindow(WindowID)
    case invalidAppID
    case invalidToken
    case tokenRequestTimedOut
    case cancelled
    case displayClosed
    case unknownSeat(SeatID)

    public var description: String {
        switch self {
        case .unavailable:
            "xdg-activation is not available on this display"
        case .foreignWindow(let windowID):
            "window \(windowID) belongs to a different display"
        case .unknownWindow(let windowID):
            "window \(windowID) is not registered on this display"
        case .closedWindow(let windowID):
            "window \(windowID) is closed"
        case .invalidAppID:
            "activation app ID must not be empty or contain NUL bytes"
        case .invalidToken:
            "activation token must not be empty or contain NUL bytes"
        case .tokenRequestTimedOut:
            "activation token request timed out"
        case .cancelled:
            "activation token request was cancelled"
        case .displayClosed:
            "display is closed"
        case .unknownSeat(let seatID):
            "seat \(seatID) is not registered on this display"
        }
    }
}
