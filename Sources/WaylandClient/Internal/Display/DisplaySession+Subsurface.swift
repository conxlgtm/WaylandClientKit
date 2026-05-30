extension DisplaySession {
    package func createSubsurfaceOnOwnerThread(
        parent parentWindow: TopLevelWindow,
        configuration subsurfaceConfiguration: SubsurfaceConfiguration
    ) throws -> SubsurfaceRoleSurface {
        connection.preconditionIsOwnerThread()
        return try SubsurfaceRoleSurface(
            id: subsurfaceIDs.next(),
            parent: parentWindow,
            connection: connection,
            configuration: subsurfaceConfiguration
        )
    }
}
