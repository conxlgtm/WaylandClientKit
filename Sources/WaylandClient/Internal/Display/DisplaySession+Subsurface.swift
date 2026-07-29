extension DisplaySession {
    package func createSubsurfaceOnOwnerThread(
        parent parentWindow: TopLevelWindow,
        configuration subsurfaceConfiguration: SubsurfaceConfiguration,
        failureSink subsurfaceFailureSink: any WindowFailureSink = DefaultWindowFailureSink()
    ) throws -> SubsurfaceRoleSurface {
        connection.preconditionIsOwnerThread()
        return try SubsurfaceRoleSurface(
            id: subsurfaceIDs.next(),
            parent: parentWindow,
            connection: connection,
            configuration: subsurfaceConfiguration,
            failureSink: subsurfaceFailureSink
        )
    }
}
