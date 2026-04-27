import WaylandRaw

public final class DisplaySession {
    private let connection: RawDisplayConnection
    private let inputRouter = InputRouter()
    private var nextWindowID: UInt64 = 1

    public init(connection rawConnection: RawDisplayConnection) {
        rawConnection.preconditionIsOwnerThread()
        connection = rawConnection
    }

    public static func connect() throws -> DisplaySession {
        let connection = try RawDisplayConnection.connect()
        try connection.completeInitialDiscovery()
        return DisplaySession(connection: connection)
    }

    public func pumpEvents(timeoutMilliseconds: Int32 = -1) throws {
        connection.preconditionIsOwnerThread()
        try connection.pumpEvents(timeoutMilliseconds: timeoutMilliseconds)
    }

    public func drainInputEvents() -> [InputEvent] {
        connection.preconditionIsOwnerThread()
        return
            connection
            .drainInputEvents()
            .flatMap { [inputRouter] event in
                inputRouter.route(event)
            }
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
