import WaylandClient

@main
enum ManagedSurfacePresentationSmoke {
    static func main() async throws {
        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.ManagedSurfacePresentationSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                eventCapacity: 128,
                inputEventCapacity: 32,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 64
            )
        ) { display in
            try await ManagedSurfaceSmokeRun(display: display).execute()
        }
    }
}
