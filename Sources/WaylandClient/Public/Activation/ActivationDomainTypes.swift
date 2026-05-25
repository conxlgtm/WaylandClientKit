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

public struct ActivationTokenRequest: Equatable, Sendable {
    public var appID: String?
    public var window: Window?
    public var seatID: SeatID?
    public var serial: InputSerial?

    public init(
        appID requestAppID: String? = nil,
        window requestWindow: Window? = nil,
        seatID requestSeatID: SeatID? = nil,
        serial requestSerial: InputSerial? = nil
    ) {
        appID = requestAppID
        window = requestWindow
        seatID = requestSeatID
        serial = requestSerial
    }
}

package struct ActivationTokenRequestPlan: Equatable, Sendable {
    package let appID: String?
    package let windowID: WindowID?
    package let seatID: SeatID?
    package let serial: InputSerial?

    package init(_ request: ActivationTokenRequest) {
        appID = request.appID
        windowID = request.window?.id
        seatID = request.seatID
        serial = request.serial
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
    case displayClosed
    case unknownSeat(SeatID)
    case incompleteSerialContext

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
        case .displayClosed:
            "display is closed"
        case .unknownSeat(let seatID):
            "seat \(seatID) is not registered on this display"
        case .incompleteSerialContext:
            "activation serial context requires both a seat ID and an input serial"
        }
    }
}
