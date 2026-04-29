import WaylandCursor
import WaylandKeyboardInterpretation
import WaylandRaw

public final class DisplaySession {
    private let connection: RawDisplayConnection
    private let inputRouter = InputRouter()
    private let keyboardInterpreter: KeyboardInterpreter
    private let cursorManager: CursorManager
    private var nextWindowID: UInt64 = 1

    public init(
        connection rawConnection: RawDisplayConnection,
        cursorConfiguration: CursorConfiguration = .init()
    ) throws {
        rawConnection.preconditionIsOwnerThread()
        connection = rawConnection
        keyboardInterpreter = try KeyboardInterpreter()
        cursorManager = try CursorManager(
            connection: rawConnection,
            configuration: cursorConfiguration
        )
    }

    public static func connect(
        cursorConfiguration: CursorConfiguration = .init()
    ) throws -> DisplaySession {
        let connection = try RawDisplayConnection.connect()
        try connection.completeInitialDiscovery()
        return try DisplaySession(
            connection: connection,
            cursorConfiguration: cursorConfiguration
        )
    }

    public func pumpEvents(timeoutMilliseconds: Int32 = -1) throws {
        connection.preconditionIsOwnerThread()
        try connection.pumpEvents(timeoutMilliseconds: timeoutMilliseconds)
    }

    public var pointerCursor: PointerCursor {
        cursorManager.pointerCursor
    }

    public func setPointerCursor(_ cursor: PointerCursor) {
        connection.preconditionIsOwnerThread()
        cursorManager.setPointerCursor(cursor)
    }

    public func drainInputEvents() -> [InputEvent] {
        connection.preconditionIsOwnerThread()

        return routeSessionInputEvents(
            from: connection.drainInputEvents(),
            inputRouter: inputRouter,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: cursorManager
        )
    }

    public func createTopLevelWindow(
        configuration windowConfiguration: WindowConfiguration = .init()
    ) throws -> TopLevelWindow {
        connection.preconditionIsOwnerThread()
        let windowID = allocateWindowID()
        let window = try TopLevelWindow(
            id: windowID,
            connection: connection,
            configuration: windowConfiguration
        )
        let surfaceID = window.surfaceID

        inputRouter.register(windowID: windowID, surfaceID: surfaceID)
        cursorManager.register(surfaceID: surfaceID)
        window.onClose = { [cursorManager, inputRouter] in
            inputRouter.unregister(surfaceID: surfaceID)
            cursorManager.unregister(surfaceID: surfaceID)
        }

        return window
    }

    private func allocateWindowID() -> WindowID {
        connection.preconditionIsOwnerThread()
        defer { nextWindowID += 1 }
        return WindowID(rawValue: nextWindowID)
    }
}

func routeSessionInputEvents(
    from rawEvents: [RawInputEvent],
    inputRouter: InputRouter,
    keyboardInterpreter: KeyboardInterpreter,
    rawInputObserver: RawInputEventObserving? = nil
) -> [InputEvent] {
    var inputEvents: [InputEvent] = []
    for rawEvent in rawEvents {
        rawInputObserver?.observe(rawEvent)
        inputEvents.append(contentsOf: inputRouter.route(rawEvent))

        for interpretedEvent in keyboardInterpreter.consume(rawEvent) {
            inputEvents.append(contentsOf: inputRouter.route(interpretedEvent))
        }
    }

    return inputEvents
}
