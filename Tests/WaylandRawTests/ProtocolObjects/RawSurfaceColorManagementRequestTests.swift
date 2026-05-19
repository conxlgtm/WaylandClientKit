import CWaylandProtocols
import Testing

@testable import WaylandRaw

@Suite(.serialized)
struct RawSurfaceColorManagementRequestTests {
    @Test
    func managerV1RejectsGetImageDescriptionBeforeRequest() async throws {
        try await withCoreMetadataRequestAndListenerRecording {
            let manager = try RawColorManager(
                pointer: try unsafe testPointer(0xC601),
                version: 1,
                proxyAdoption: try testAdoptionContext()
            )
            defer { manager.destroy() }
            let reference = try testImageDescriptionReference(pointer: 0xC602)
            defer { reference.destroy() }

            expectMetadataListener(object: 0xC601)
            #expect(
                throws: RuntimeError.unsupportedProtocolVersion(
                    interface: "wp_color_manager_v1.get_image_description",
                    minimum: 2,
                    actual: 1
                )
            ) {
                try manager.imageDescription(for: reference)
            }
            expectMetadataRequestCallCount(0)
        }
    }

    @Test
    func managerV2AllowsGetImageDescription() async throws {
        try await withCoreMetadataRequestAndListenerRecording {
            let manager = try RawColorManager(
                pointer: try unsafe testPointer(0xC701),
                version: 2,
                proxyAdoption: try testAdoptionContext()
            )
            defer { manager.destroy() }
            let reference = try testImageDescriptionReference(pointer: 0xC702)
            defer { reference.destroy() }

            let description = try manager.imageDescription(for: reference)
            defer { description.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_COLOR_MANAGER_GET_IMAGE_DESCRIPTION,
                callCount: 1,
                object: 0xC701,
                reference: 0xC702
            )
        }
    }

    @Test
    func surfaceFactoryRejectsDuplicate() async throws {
        try await withColorManagerFixture { surface, manager in
            let colorSurface = try manager.surface(for: surface)
            defer { colorSurface.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_COLOR_MANAGER_GET_SURFACE,
                callCount: 1,
                object: 0xC802,
                surface: 0xC801
            )

            #expect(
                throws: RuntimeError.invalidArgument(
                    RawSurfaceMetadataError.colorManagementSurfaceAlreadyExists
                        .description
                )
            ) {
                try manager.surface(for: surface)
            }
            expectMetadataRequestCallCount(1)
        }
    }

    @Test
    func surfaceSettersRecordRequests() async throws {
        try await withColorManagerFixture { surface, manager in
            let colorSurface = try manager.surface(for: surface)
            defer { colorSurface.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_COLOR_MANAGER_GET_SURFACE,
                callCount: 1,
                object: 0xC802,
                surface: 0xC801
            )

            let imageDescription = RawImageDescription(
                pointer: try unsafe testPointer(0xC803),
                destroy: unsafe ignoreTestMetadataDestroy
            )
            defer { imageDescription.destroy() }
            colorSurface.setImageDescription(imageDescription, renderIntent: .relative)
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_COLOR_SURFACE_SET_IMAGE_DESCRIPTION,
                callCount: 2,
                object: 0xC706,
                imageDescription: 0xC803,
                renderIntent: RawColorRenderIntent.relative.rawValue
            )

            colorSurface.unsetImageDescription()
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_COLOR_SURFACE_UNSET_IMAGE_DESCRIPTION,
                callCount: 3,
                object: 0xC706
            )
        }
    }

    @Test
    func surfaceDestroyAllowsReplacement() async throws {
        try await withColorManagerFixture { surface, manager in
            let colorSurface = try manager.surface(for: surface)
            colorSurface.destroy()

            let replacement = try manager.surface(for: surface)
            defer { replacement.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_COLOR_MANAGER_GET_SURFACE,
                callCount: 2,
                object: 0xC802,
                surface: 0xC801
            )
        }
    }
}

private func withColorManagerFixture(
    _ operation: (RawSurface, RawColorManager) throws -> Void
) async throws {
    try await withCoreMetadataRequestAndListenerRecording {
        let surface = try testSurface(pointer: 0xC801)
        defer { surface.destroy() }
        let manager = try RawColorManager(
            pointer: try unsafe testPointer(0xC802),
            version: 2,
            proxyAdoption: try testAdoptionContext()
        )
        defer { manager.destroy() }
        expectMetadataListener(object: 0xC802)
        try operation(surface, manager)
    }
}
