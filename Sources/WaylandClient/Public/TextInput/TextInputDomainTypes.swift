public enum TextInputError: Error, Equatable, Sendable, CustomStringConvertible {
    case unavailable
    case unknownSeat(SeatID)
    case foreignWindow(WindowID)
    case surroundingTextContainsNUL
    case surroundingTextTooLarge(byteCount: Int, limit: Int)
    case surroundingTextOffsetOutOfBounds(offset: Int, byteCount: Int)
    case surroundingTextOffsetOverflow(byteCount: Int)

    public var description: String {
        switch self {
        case .unavailable:
            "text-input protocol is unavailable"
        case .unknownSeat(let seatID):
            "unknown text-input seat \(seatID)"
        case .foreignWindow(let windowID):
            "window belongs to another display: \(windowID)"
        case .surroundingTextContainsNUL:
            "surrounding text must not contain a NUL byte"
        case .surroundingTextTooLarge(let byteCount, let limit):
            "surrounding text is \(byteCount) UTF-8 bytes, exceeding limit \(limit)"
        case .surroundingTextOffsetOutOfBounds(let offset, let byteCount):
            "surrounding text byte offset \(offset) is outside 0...\(byteCount)"
        case .surroundingTextOffsetOverflow(let byteCount):
            "surrounding text byte offset \(byteCount) exceeds Int32"
        }
    }
}

public struct TextInputSurroundingText: Equatable, Sendable {
    package static let maximumUTF8ByteCount = 4_000

    public let text: String
    public let cursorUTF8Offset: Int
    public let anchorUTF8Offset: Int

    public init(
        text requestText: String,
        cursorUTF8Offset requestCursorUTF8Offset: Int,
        anchorUTF8Offset requestAnchorUTF8Offset: Int
    ) throws {
        guard !requestText.utf8.contains(0) else {
            throw TextInputError.surroundingTextContainsNUL
        }

        let byteCount = requestText.utf8.count
        guard byteCount <= Self.maximumUTF8ByteCount else {
            throw TextInputError.surroundingTextTooLarge(
                byteCount: byteCount,
                limit: Self.maximumUTF8ByteCount
            )
        }

        try Self.validateOffset(
            requestCursorUTF8Offset,
            byteCount: byteCount
        )
        try Self.validateOffset(
            requestAnchorUTF8Offset,
            byteCount: byteCount
        )

        text = requestText
        cursorUTF8Offset = requestCursorUTF8Offset
        anchorUTF8Offset = requestAnchorUTF8Offset
    }

    private static func validateOffset(
        _ offset: Int,
        byteCount: Int
    ) throws(TextInputError) {
        guard offset >= 0 else {
            throw .surroundingTextOffsetOutOfBounds(
                offset: offset,
                byteCount: byteCount
            )
        }

        guard offset <= Int(Int32.max) else {
            throw .surroundingTextOffsetOverflow(byteCount: offset)
        }

        guard offset <= byteCount else {
            throw .surroundingTextOffsetOutOfBounds(
                offset: offset,
                byteCount: byteCount
            )
        }
    }
}

public struct TextInputContentHints: OptionSet, Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue hintsRawValue: UInt32) {
        rawValue = hintsRawValue
    }

    public static let completion = Self(rawValue: 0x1)
    public static let spellcheck = Self(rawValue: 0x2)
    public static let autoCapitalization = Self(rawValue: 0x4)
    public static let lowercase = Self(rawValue: 0x8)
    public static let uppercase = Self(rawValue: 0x10)
    public static let titlecase = Self(rawValue: 0x20)
    public static let hiddenText = Self(rawValue: 0x40)
    public static let sensitiveData = Self(rawValue: 0x80)
    public static let latin = Self(rawValue: 0x100)
    public static let multiline = Self(rawValue: 0x200)
    public static let onScreenInputProvided = Self(rawValue: 0x400)
    public static let noEmoji = Self(rawValue: 0x800)
    public static let preeditShown = Self(rawValue: 0x1000)
}

public struct TextInputContentPurpose: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue purposeRawValue: UInt32) {
        rawValue = purposeRawValue
    }

    public static let normal = Self(rawValue: 0)
    public static let alpha = Self(rawValue: 1)
    public static let digits = Self(rawValue: 2)
    public static let number = Self(rawValue: 3)
    public static let phone = Self(rawValue: 4)
    public static let url = Self(rawValue: 5)
    public static let email = Self(rawValue: 6)
    public static let name = Self(rawValue: 7)
    public static let password = Self(rawValue: 8)
    public static let pin = Self(rawValue: 9)
    public static let date = Self(rawValue: 10)
    public static let time = Self(rawValue: 11)
    public static let datetime = Self(rawValue: 12)
    public static let terminal = Self(rawValue: 13)
}

public struct TextInputChangeCause: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue causeRawValue: UInt32) {
        rawValue = causeRawValue
    }

    public static let inputMethod = Self(rawValue: 0)
    public static let other = Self(rawValue: 1)
}

public struct TextInputAction: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue actionRawValue: UInt32) {
        rawValue = actionRawValue
    }

    public static let none = Self(rawValue: 0)
    public static let submit = Self(rawValue: 1)
}

public struct TextInputPreeditHintKind: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue hintRawValue: UInt32) {
        rawValue = hintRawValue
    }

    public static let whole = Self(rawValue: 1)
    public static let selection = Self(rawValue: 2)
    public static let prediction = Self(rawValue: 3)
    public static let prefix = Self(rawValue: 4)
    public static let suffix = Self(rawValue: 5)
    public static let spellingError = Self(rawValue: 6)
    public static let composeError = Self(rawValue: 7)
}

public struct TextInputPreeditHint: Equatable, Sendable {
    public let start: UInt32
    public let end: UInt32
    public let kind: TextInputPreeditHintKind

    public init(
        start hintStart: UInt32,
        end hintEnd: UInt32,
        kind hintKind: TextInputPreeditHintKind
    ) {
        start = hintStart
        end = hintEnd
        kind = hintKind
    }
}

public struct TextInputFocusEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let target: InputEventTarget

    public init(seatID eventSeatID: SeatID, target eventTarget: InputEventTarget) {
        seatID = eventSeatID
        target = eventTarget
    }
}

public struct TextInputPreeditEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let text: String
    public let cursorBegin: Int32
    public let cursorEnd: Int32
    public let hints: [TextInputPreeditHint]

    public init(
        seatID eventSeatID: SeatID,
        text eventText: String,
        cursorBegin eventCursorBegin: Int32,
        cursorEnd eventCursorEnd: Int32,
        hints eventHints: [TextInputPreeditHint]
    ) {
        seatID = eventSeatID
        text = eventText
        cursorBegin = eventCursorBegin
        cursorEnd = eventCursorEnd
        hints = eventHints
    }
}

public struct TextInputCommitEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let text: String

    public init(seatID eventSeatID: SeatID, text eventText: String) {
        seatID = eventSeatID
        text = eventText
    }
}

public struct TextInputDeleteSurroundingTextEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let beforeLength: UInt32
    public let afterLength: UInt32

    public init(
        seatID eventSeatID: SeatID,
        beforeLength eventBeforeLength: UInt32,
        afterLength eventAfterLength: UInt32
    ) {
        seatID = eventSeatID
        beforeLength = eventBeforeLength
        afterLength = eventAfterLength
    }
}

public struct TextInputActionEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let action: TextInputAction
    public let serial: UInt32

    public init(
        seatID eventSeatID: SeatID,
        action eventAction: TextInputAction,
        serial eventSerial: UInt32
    ) {
        seatID = eventSeatID
        action = eventAction
        serial = eventSerial
    }
}

public enum TextInputLanguage: Equatable, Sendable {
    case unknown
    case tag(String)
}

public struct TextInputLanguageEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let language: TextInputLanguage

    public init(seatID eventSeatID: SeatID, language eventLanguage: TextInputLanguage) {
        seatID = eventSeatID
        language = eventLanguage
    }
}

public struct TextInputDoneEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let serial: UInt32

    public init(seatID eventSeatID: SeatID, serial eventSerial: UInt32) {
        seatID = eventSeatID
        serial = eventSerial
    }
}

public enum TextInputEvent: Equatable, Sendable {
    case entered(TextInputFocusEvent)
    case left(TextInputFocusEvent)
    case preedit(TextInputPreeditEvent)
    case committed(TextInputCommitEvent)
    case deleteSurroundingText(TextInputDeleteSurroundingTextEvent)
    case action(TextInputActionEvent)
    case language(TextInputLanguageEvent)
    case done(TextInputDoneEvent)
}
