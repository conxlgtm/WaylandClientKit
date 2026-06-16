public struct WindowIconName: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ iconName: String) throws {
        guard !iconName.isEmpty else {
            throw ClientError.display(.emptyWindowIconName)
        }
        guard !iconName.contains("\0") else {
            throw ClientError.display(.windowIconNameContainsNUL)
        }

        value = iconName
    }

    public var description: String {
        value
    }
}

public struct WindowIconImage: Equatable, Sendable {
    public let size: PositivePixelSize
    public let scale: PositiveInt32
    public let pixels: [UInt32]

    public init(
        size imageSize: PositivePixelSize,
        pixels xrgb8888Pixels: [UInt32]
    ) throws {
        try self.init(
            size: imageSize,
            scale: try PositiveInt32(1),
            pixels: xrgb8888Pixels
        )
    }

    public init(
        size imageSize: PositivePixelSize,
        scale imageScale: PositiveInt32,
        pixels xrgb8888Pixels: [UInt32]
    ) throws {
        guard imageSize.width == imageSize.height else {
            throw ClientError.display(
                .nonSquareWindowIconImage(
                    width: imageSize.width.rawValue,
                    height: imageSize.height.rawValue
                )
            )
        }

        let expected = try Self.expectedPixelCount(
            width: Int(imageSize.width.rawValue),
            height: Int(imageSize.height.rawValue),
            actualForError: xrgb8888Pixels.count
        )
        guard xrgb8888Pixels.count == expected else {
            throw ClientError.display(
                .invalidWindowIconImagePixelCount(
                    expected: expected,
                    actual: xrgb8888Pixels.count
                )
            )
        }

        size = imageSize
        scale = imageScale
        pixels = xrgb8888Pixels
    }

    public static func solid(
        size imageSize: PositivePixelSize,
        color xrgb8888Color: UInt32
    ) throws -> WindowIconImage {
        try solid(
            size: imageSize,
            scale: try PositiveInt32(1),
            color: xrgb8888Color
        )
    }

    public static func solid(
        size imageSize: PositivePixelSize,
        scale imageScale: PositiveInt32,
        color xrgb8888Color: UInt32
    ) throws -> WindowIconImage {
        let expected = try expectedPixelCount(
            width: Int(imageSize.width.rawValue),
            height: Int(imageSize.height.rawValue),
            actualForError: 0
        )
        return try WindowIconImage(
            size: imageSize,
            scale: imageScale,
            pixels: Array(repeating: xrgb8888Color, count: expected)
        )
    }

    private static func expectedPixelCount(
        width: Int,
        height: Int,
        actualForError actual: Int
    ) throws -> Int {
        let (expected, overflowed) = width.multipliedReportingOverflow(by: height)
        guard !overflowed else {
            throw ClientError.display(
                .invalidWindowIconImagePixelCount(expected: Int.max, actual: actual)
            )
        }

        return expected
    }
}

public enum WindowIcon: Equatable, Sendable {
    case none
    case named(WindowIconName)
    case xrgb8888(WindowIconImage)
}

public struct WindowDialogID:
    Hashable,
    Sendable,
    CustomStringConvertible,
    UInt64WaylandEntityID
{
    package let rawValue: UInt64

    package init(rawValue dialogRawValue: UInt64) {
        rawValue = dialogRawValue
    }

    public var description: String {
        "window-dialog-\(rawValue)"
    }
}

public struct WindowDialog: Sendable, Hashable, Identifiable {
    public let id: WindowDialogID
    public let childWindowID: WindowID
    public let parentWindowID: WindowID

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<WindowDialogID>

    package init(
        id dialogID: WindowDialogID,
        childWindowID dialogChildWindowID: WindowID,
        parentWindowID dialogParentWindowID: WindowID,
        display owningDisplay: WaylandDisplay
    ) {
        id = dialogID
        childWindowID = dialogChildWindowID
        parentWindowID = dialogParentWindowID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: dialogID, display: owningDisplay)
    }

    package func isOwned(by owningDisplay: WaylandDisplay) -> Bool {
        ownership.isOwned(by: owningDisplay)
    }

    public func setModal() async throws {
        guard isOwned(by: display) else {
            throw ClientError.display(.foreignWindowDialog(id))
        }

        try await display.setWindowDialogModal(id, modal: true)
    }

    public func unsetModal() async throws {
        guard isOwned(by: display) else {
            throw ClientError.display(.foreignWindowDialog(id))
        }

        try await display.setWindowDialogModal(id, modal: false)
    }

    public func destroy() async throws {
        guard isOwned(by: display) else {
            throw ClientError.display(.foreignWindowDialog(id))
        }

        try await display.destroyWindowDialog(id)
    }

    public static func == (lhs: WindowDialog, rhs: WindowDialog) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}

public struct IdleInhibitorID:
    Hashable,
    Sendable,
    CustomStringConvertible,
    UInt64WaylandEntityID
{
    package let rawValue: UInt64

    package init(rawValue inhibitorRawValue: UInt64) {
        rawValue = inhibitorRawValue
    }

    public var description: String {
        "idle-inhibitor-\(rawValue)"
    }
}

public struct IdleInhibitor: Sendable, Hashable, Identifiable {
    public let id: IdleInhibitorID

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<IdleInhibitorID>

    package init(id inhibitorID: IdleInhibitorID, display owningDisplay: WaylandDisplay) {
        id = inhibitorID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: inhibitorID, display: owningDisplay)
    }

    package func isOwned(by owningDisplay: WaylandDisplay) -> Bool {
        ownership.isOwned(by: owningDisplay)
    }

    public func destroy() async throws {
        guard isOwned(by: display) else {
            throw ClientError.display(.foreignIdleInhibitor(id))
        }

        try await display.destroyIdleInhibitor(id)
    }

    public static func == (lhs: IdleInhibitor, rhs: IdleInhibitor) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}

public struct KeyboardShortcutsInhibitorID:
    Hashable,
    Sendable,
    CustomStringConvertible,
    UInt64WaylandEntityID
{
    package let rawValue: UInt64

    package init(rawValue inhibitorRawValue: UInt64) {
        rawValue = inhibitorRawValue
    }

    public var description: String {
        "keyboard-shortcuts-inhibitor-\(rawValue)"
    }
}

public struct KeyboardShortcutsInhibitor: Sendable, Hashable, Identifiable {
    public let id: KeyboardShortcutsInhibitorID
    public let windowID: WindowID
    public let seatID: SeatID

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<KeyboardShortcutsInhibitorID>

    package init(
        id inhibitorID: KeyboardShortcutsInhibitorID,
        windowID inhibitedWindowID: WindowID,
        seatID inhibitedSeatID: SeatID,
        display owningDisplay: WaylandDisplay
    ) {
        id = inhibitorID
        windowID = inhibitedWindowID
        seatID = inhibitedSeatID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: inhibitorID, display: owningDisplay)
    }

    package func isOwned(by owningDisplay: WaylandDisplay) -> Bool {
        ownership.isOwned(by: owningDisplay)
    }

    public func destroy() async throws {
        guard isOwned(by: display) else {
            throw ClientError.display(.foreignKeyboardShortcutsInhibitor(id))
        }

        try await display.destroyKeyboardShortcutsInhibitor(id)
    }

    public static func == (
        lhs: KeyboardShortcutsInhibitor,
        rhs: KeyboardShortcutsInhibitor
    ) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}

public enum KeyboardShortcutsInhibitorActivity: Equatable, Sendable {
    case active
    case inactive
}

public struct KeyboardShortcutsInhibitorEvent: Equatable, Sendable {
    public let inhibitorID: KeyboardShortcutsInhibitorID
    public let windowID: WindowID
    public let seatID: SeatID
    public let activity: KeyboardShortcutsInhibitorActivity

    public init(
        inhibitorID eventInhibitorID: KeyboardShortcutsInhibitorID,
        windowID eventWindowID: WindowID,
        seatID eventSeatID: SeatID,
        activity eventActivity: KeyboardShortcutsInhibitorActivity
    ) {
        inhibitorID = eventInhibitorID
        windowID = eventWindowID
        seatID = eventSeatID
        activity = eventActivity
    }
}

public struct ForeignToplevelID:
    Hashable,
    Sendable,
    CustomStringConvertible,
    UInt64WaylandEntityID
{
    package let rawValue: UInt64

    public init(rawValue toplevelRawValue: UInt64) {
        rawValue = toplevelRawValue
    }

    public var description: String {
        "foreign-toplevel-\(rawValue)"
    }
}

public struct ForeignToplevelSnapshot: Equatable, Sendable, Identifiable {
    public let id: ForeignToplevelID
    public let protocolIdentifier: String?
    public let title: String?
    public let appID: String?

    public init(
        id toplevelID: ForeignToplevelID,
        protocolIdentifier toplevelProtocolIdentifier: String?,
        title toplevelTitle: String?,
        appID toplevelAppID: String?
    ) {
        id = toplevelID
        protocolIdentifier = toplevelProtocolIdentifier
        title = toplevelTitle
        appID = toplevelAppID
    }
}

public enum ForeignToplevelEvent: Equatable, Sendable {
    case added(ForeignToplevelSnapshot)
    case updated(ForeignToplevelSnapshot)
    case removed(ForeignToplevelID)
}

public struct ForeignToplevelListSnapshot: Equatable, Sendable {
    public let toplevels: [ForeignToplevelSnapshot]
    public let events: [ForeignToplevelEvent]

    public init(
        toplevels snapshotToplevels: [ForeignToplevelSnapshot],
        events snapshotEvents: [ForeignToplevelEvent]
    ) {
        toplevels = snapshotToplevels
        events = snapshotEvents
    }
}
