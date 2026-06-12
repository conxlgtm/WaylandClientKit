extension WaylandDisplay {
    package func installInputSerialAction(
        _ handler: @escaping InputSerialActionHandler
    ) throws -> InputSerialActionID {
        try requireCore().installInputSerialAction(handler)
    }

    package func removeInputSerialAction(_ actionID: InputSerialActionID) {
        try? requireCore().removeInputSerialAction(actionID)
    }
}
