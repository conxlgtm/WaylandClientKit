import Testing
import WaylandClient

@Suite("Managed surface presentation public API surface")
struct ManagedSurfacePresentationAPISurfaceTests {
    @Test
    func softwarePresentationOutcomesCompileForExternalClients() {
        let outcomes: [SoftwarePresentationOutcome] = [
            .presented,
            .superseded,
            .deferred,
            .closed,
        ]

        #expect(Set(outcomes).count == 4)
        _ = useAtomicWindowPresentationAPI
        _ = useAtomicPopupPresentationAPI
    }

    private func useAtomicWindowPresentationAPI(
        _ window: Window
    ) async throws -> [SoftwarePresentationOutcome] {
        let dirtyRectangle = try LogicalRect(x: 0, y: 0, width: 1, height: 1)
        let metadata = SurfaceFrameMetadata(
            contentType: .photo,
            presentationHint: .vsync,
            alpha: .opaque,
            colorRepresentation: SurfaceColorRepresentation(
                alphaMode: .premultipliedElectrical
            ),
            damage: try SurfaceDamageRegion([dirtyRectangle])
        )

        let simpleShow = try await window.show(
            metadata: metadata,
            requestPresentationFeedback: true,
            timeoutMilliseconds: 1_000
        ) { _ in () }
        let simpleRedraw = try await window.redraw(
            metadata: metadata,
            requestPresentationFeedback: true
        ) { _ in () }
        let preparedShow = try await window.show(
            metadata: metadata,
            requestPresentationFeedback: true,
            timeoutMilliseconds: 1_000,
            preparing: { reservation in reservation.id },
            { _, _ in () }
        )
        let preparedRedraw = try await window.redraw(
            metadata: metadata,
            requestPresentationFeedback: true,
            preparing: { reservation in reservation.id },
            { _, _ in () }
        )
        return [simpleShow, simpleRedraw, preparedShow, preparedRedraw]
    }

    private func useAtomicPopupPresentationAPI(
        _ popup: PopupSurface
    ) async throws -> [SoftwarePresentationOutcome] {
        let simpleShow = try await popup.show(
            metadata: .default,
            requestPresentationFeedback: true,
            timeoutMilliseconds: 1_000
        ) { _ in () }
        let simpleRedraw = try await popup.redraw(
            metadata: .default,
            requestPresentationFeedback: true
        ) { _ in () }
        let preparedShow = try await popup.show(
            metadata: .default,
            requestPresentationFeedback: true,
            timeoutMilliseconds: 1_000,
            preparing: { reservation in reservation.id },
            { _, _ in () }
        )
        let preparedRedraw = try await popup.redraw(
            metadata: .default,
            requestPresentationFeedback: true,
            preparing: { reservation in reservation.id },
            { _, _ in () }
        )
        return [simpleShow, simpleRedraw, preparedShow, preparedRedraw]
    }
}
