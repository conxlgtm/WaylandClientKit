import WaylandKeyboardInterpretation
import WaylandRaw

public final class DisplaySession {
    private let connection: RawDisplayConnection
    private let inputRouter = InputRouter()
    private let keyboardInterpreter: KeyboardInterpreter
    private var nextWindowID: UInt64 = 1

    public init(connection rawConnection: RawDisplayConnection) throws {
        rawConnection.preconditionIsOwnerThread()
        connection = rawConnection
        keyboardInterpreter = try KeyboardInterpreter()
    }

    public static func connect() throws -> DisplaySession {
        let connection = try RawDisplayConnection.connect()
        try connection.completeInitialDiscovery()
        return try DisplaySession(connection: connection)
    }

    public func pumpEvents(timeoutMilliseconds: Int32 = -1) throws {
        connection.preconditionIsOwnerThread()
        try connection.pumpEvents(timeoutMilliseconds: timeoutMilliseconds)
    }

    public func drainInputEvents() -> [InputEvent] {
        connection.preconditionIsOwnerThread()

        return routeSessionInputEvents(
            from: connection.drainInputEvents(),
            inputRouter: inputRouter,
            keyboardInterpreter: keyboardInterpreter
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
        window.onClose = { [inputRouter] in
            inputRouter.unregister(surfaceID: surfaceID)
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
    keyboardInterpreter: KeyboardInterpreter
) -> [InputEvent] {
    var inputEvents: [InputEvent] = []
    for rawEvent in rawEvents {
        inputEvents.append(contentsOf: inputRouter.route(rawEvent))

        for interpretedEvent in keyboardInterpreter.consume(rawEvent) {
            inputEvents.append(contentsOf: inputRouter.route(interpretedEvent))
        }
    }

    return inputEvents
}
