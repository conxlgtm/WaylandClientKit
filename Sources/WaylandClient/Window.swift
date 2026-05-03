public struct Window: Sendable, Hashable {
    public let id: WindowID
    private let display: WaylandDisplay
    private let displayIdentity: ObjectIdentifier

    package init(id windowID: WindowID, display owningDisplay: WaylandDisplay) {
        id = windowID
        display = owningDisplay
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    public func show(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.showWindow(id, timeoutMilliseconds: timeoutMilliseconds, draw)
    }

    public func redraw(
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redraw(id, draw)
    }

    public func close() async {
        await display.closeWindow(id)
    }

    public func requestRedraw() async throws {
        try await display.requestRedraw(id)
    }

    public var isClosed: Bool {
        get async throws {
            try await display.windowIsClosed(id)
        }
    }

    public var needsRedraw: Bool {
        get async throws {
            try await display.windowNeedsRedraw(id)
        }
    }

    public var decorationMode: WindowDecorationMode {
        get async throws {
            try await display.windowDecorationMode(id)
        }
    }

    public static func == (lhs: Window, rhs: Window) -> Bool {
        lhs.id == rhs.id && lhs.displayIdentity == rhs.displayIdentity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayIdentity)
        hasher.combine(id)
    }
}
