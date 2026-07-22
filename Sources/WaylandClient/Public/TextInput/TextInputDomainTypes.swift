public enum TextInputError: Error, Equatable, Sendable, CustomStringConvertible {
    case unavailable
    case unknownSeat(SeatID)
    case foreignWindow(WindowID)
    case inactiveSession(seatID: SeatID, operation: TextInputRequestOperation)
    case unsupportedVersion(
        operation: TextInputRequestOperation,
        required: UInt32,
        available: UInt32
    )
    case surroundingTextContainsNUL
    case surroundingTextTooLarge(byteCount: Int, limit: Int)
    case surroundingTextOffsetOutOfBounds(offset: Int, byteCount: Int)
    case surroundingTextOffsetInsideCodePoint(offset: Int)
    case surroundingTextOffsetOverflow(byteCount: Int)
    case surroundingTextIndexOutOfBounds

    public var description: String {
        switch self {
        case .unavailable:
            "text-input protocol is unavailable"
        case .unknownSeat(let seatID):
            "unknown text-input seat \(seatID)"
        case .foreignWindow(let windowID):
            "window belongs to another display: \(windowID)"
        case .inactiveSession(let seatID, let operation):
            "text-input \(operation.description) requires an enabled session for seat \(seatID)"
        case .unsupportedVersion(let operation, let required, let available):
            "text-input \(operation.description) requires protocol v\(required), "
                + "available v\(available)"
        case .surroundingTextContainsNUL:
            "surrounding text must not contain a NUL byte"
        case .surroundingTextTooLarge(let byteCount, let limit):
            "surrounding text is \(byteCount) UTF-8 bytes, exceeding limit \(limit)"
        case .surroundingTextOffsetOutOfBounds(let offset, let byteCount):
            "surrounding text byte offset \(offset) is outside 0...\(byteCount)"
        case .surroundingTextOffsetInsideCodePoint(let offset):
            "surrounding text byte offset \(offset) is inside a UTF-8 code point"
        case .surroundingTextOffsetOverflow(let byteCount):
            "surrounding text byte offset \(byteCount) exceeds Int32"
        case .surroundingTextIndexOutOfBounds:
            "surrounding text index does not belong to the provided text"
        }
    }
}

public enum TextInputRequestOperation: Equatable, Sendable, CustomStringConvertible {
    case enable
    case disable
    case setSurroundingText
    case setTextChangeCause
    case setContentType
    case setCursorRectangle
    case commit
    case showInputPanel
    case hideInputPanel

    public var description: String {
        switch self {
        case .enable:
            "enable"
        case .disable:
            "disable"
        case .setSurroundingText:
            "set_surrounding_text"
        case .setTextChangeCause:
            "set_text_change_cause"
        case .setContentType:
            "set_content_type"
        case .setCursorRectangle:
            "set_cursor_rectangle"
        case .commit:
            "commit"
        case .showInputPanel:
            "show_input_panel"
        case .hideInputPanel:
            "hide_input_panel"
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
            in: requestText,
            byteCount: byteCount
        )
        try Self.validateOffset(
            requestAnchorUTF8Offset,
            in: requestText,
            byteCount: byteCount
        )

        text = requestText
        cursorUTF8Offset = requestCursorUTF8Offset
        anchorUTF8Offset = requestAnchorUTF8Offset
    }

    public init(
        text requestText: String,
        cursor requestCursor: String.Index,
        anchor requestAnchor: String.Index
    ) throws {
        let cursorOffset = try Self.utf8Offset(for: requestCursor, in: requestText)
        let anchorOffset = try Self.utf8Offset(for: requestAnchor, in: requestText)
        try self.init(
            text: requestText,
            cursorUTF8Offset: cursorOffset,
            anchorUTF8Offset: anchorOffset
        )
    }

    public static func insertionPoint(
        _ text: String,
        cursor: String.Index
    ) throws -> TextInputSurroundingText {
        try TextInputSurroundingText(
            text: text,
            cursor: cursor,
            anchor: cursor
        )
    }

    private static func utf8Offset(
        for index: String.Index,
        in text: String
    ) throws(TextInputError) -> Int {
        guard let utf8Index = index.samePosition(in: text.utf8) else {
            throw .surroundingTextIndexOutOfBounds
        }

        return text.utf8.distance(from: text.utf8.startIndex, to: utf8Index)
    }

    private static func validateOffset(
        _ offset: Int,
        in text: String,
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

        guard isCodePointBoundary(offset, in: text) else {
            throw .surroundingTextOffsetInsideCodePoint(offset: offset)
        }
    }

    private static func isCodePointBoundary(_ offset: Int, in text: String) -> Bool {
        guard offset != 0, offset != text.utf8.count else {
            return true
        }

        let index = text.utf8.index(text.utf8.startIndex, offsetBy: offset)
        return (text.utf8[index] & 0b1100_0000) != 0b1000_0000
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

public struct TextInputCommitSerial:
    RawRepresentable,
    Equatable,
    Hashable,
    Sendable
{
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public struct TextInputPreedit: Equatable, Sendable {
    public let text: String
    public let cursorBegin: Int32
    public let cursorEnd: Int32
    public let hints: [TextInputPreeditHint]

    public init(
        text: String,
        cursorBegin: Int32,
        cursorEnd: Int32,
        hints: [TextInputPreeditHint]
    ) {
        self.text = text
        self.cursorBegin = cursorBegin
        self.cursorEnd = cursorEnd
        self.hints = hints
    }
}

public struct TextInputDeletion: Equatable, Sendable {
    public let beforeLength: UInt32
    public let afterLength: UInt32

    public init(
        beforeLength: UInt32,
        afterLength: UInt32
    ) {
        self.beforeLength = beforeLength
        self.afterLength = afterLength
    }
}

public struct TextInputActionEvent: Equatable, Sendable {
    public let action: TextInputAction
    public let serial: UInt32

    public init(action: TextInputAction, serial: UInt32) {
        self.action = action
        self.serial = serial
    }
}

public struct TextInputTransaction: Equatable, Sendable {
    public let seatID: SeatID
    public let target: InputEventTarget
    public let serial: TextInputCommitSerial
    public let matchesLatestCommit: Bool

    public let preedit: TextInputPreedit?
    public let deletion: TextInputDeletion?
    public let committedText: String?
    public let action: TextInputActionEvent?

    public init(
        seatID: SeatID,
        target: InputEventTarget,
        serial: TextInputCommitSerial,
        matchesLatestCommit: Bool,
        preedit: TextInputPreedit?,
        deletion: TextInputDeletion?,
        committedText: String?,
        action: TextInputActionEvent?
    ) {
        self.seatID = seatID
        self.target = target
        self.serial = serial
        self.matchesLatestCommit = matchesLatestCommit
        self.preedit = preedit
        self.deletion = deletion
        self.committedText = committedText
        self.action = action
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

public struct TextInputDiagnostic: Equatable, Sendable {
    public let seatID: SeatID?
    public let operation: TextInputDiagnosticOperation
    public let message: String

    public init(
        seatID diagnosticSeatID: SeatID?,
        operation diagnosticOperation: TextInputDiagnosticOperation,
        message diagnosticMessage: String
    ) {
        seatID = diagnosticSeatID
        operation = diagnosticOperation
        message = diagnosticMessage
    }
}

public enum TextInputDiagnosticOperation: Equatable, Sendable {
    case unavailable
    case listener
    case invalidEventOrder
    case invalidRequest(TextInputRequestOperation)
    case unknownProtocolValue
    case seatRemoved
}

public enum TextInputEvent: Equatable, Sendable {
    case entered(TextInputFocusEvent)
    case left(TextInputFocusEvent)
    case transaction(TextInputTransaction)
    case language(TextInputLanguageEvent)
    case diagnostic(TextInputDiagnostic)
}
