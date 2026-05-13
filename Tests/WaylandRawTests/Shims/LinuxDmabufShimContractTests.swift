import CWaylandProtocols
import Testing
import WaylandTestSupport

@Suite(.serialized)
struct LinuxDmabufRequestShimContractTests {
    @Test
    func dmabufBufferParamsAddPreservesPlaneOffsetStrideAndModifierHalves() async throws {
        let params = try unsafe #require(OpaquePointer(bitPattern: 0x1001))

        try await assertDmabufRequest(
            expectedKind: SWL_TEST_DMABUF_BUFFER_PARAMS_ADD,
            object: params
        ) {
            unsafe swl_zwp_linux_buffer_params_v1_add(
                params,
                17,
                2,
                4_096,
                256,
                0x0102_0304,
                0xA0B0_C0D0
            )
            let record = unsafe swl_test_dmabuf_request_record()
            #expect(unsafe record.fd == 17)
            #expect(unsafe record.plane_idx == 2)
            #expect(unsafe record.offset == 4_096)
            #expect(unsafe record.stride == 256)
            #expect(unsafe record.modifier_hi == 0x0102_0304)
            #expect(unsafe record.modifier_lo == 0xA0B0_C0D0)
        }
    }

    @Test
    func dmabufBufferParamsCreatePreservesDimensionsFormatAndFlags() async throws {
        let params = try unsafe #require(OpaquePointer(bitPattern: 0x2002))

        try await assertDmabufRequest(
            expectedKind: SWL_TEST_DMABUF_BUFFER_PARAMS_CREATE,
            object: params
        ) {
            unsafe swl_zwp_linux_buffer_params_v1_create(
                params,
                1_920,
                1_080,
                0x3432_5258,
                5
            )
            let record = unsafe swl_test_dmabuf_request_record()
            #expect(unsafe record.width == 1_920)
            #expect(unsafe record.height == 1_080)
            #expect(unsafe record.format == 0x3432_5258)
            #expect(unsafe record.flags == 5)
        }
    }

    @Test
    func dmabufFeedbackRequestsUseDefaultAndSurfaceTargets() async throws {
        let linuxDmabuf = try unsafe #require(OpaquePointer(bitPattern: 0x3003))
        let surface = try unsafe #require(OpaquePointer(bitPattern: 0x4004))

        try await assertDmabufRequest(
            expectedKind: SWL_TEST_DMABUF_GET_DEFAULT_FEEDBACK,
            object: linuxDmabuf
        ) {
            _ = unsafe swl_zwp_linux_dmabuf_v1_get_default_feedback(linuxDmabuf)
        }

        try await assertDmabufRequest(
            expectedKind: SWL_TEST_DMABUF_GET_SURFACE_FEEDBACK,
            object: linuxDmabuf,
            surface: surface
        ) {
            _ = unsafe swl_zwp_linux_dmabuf_v1_get_surface_feedback(
                linuxDmabuf,
                surface
            )
        }
    }

    @safe
    private func assertDmabufRequest(
        expectedKind: swl_test_dmabuf_request_kind,
        object: OpaquePointer?,
        surface: OpaquePointer? = nil,
        request: () -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        try await DmabufRequestRecordingGate.withExclusiveRecording {
            swl_test_dmabuf_request_recording_begin()
            defer { swl_test_dmabuf_request_recording_end() }

            request()

            let record = unsafe swl_test_dmabuf_request_record()
            #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
            #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
            #expect(
                unsafe record.object == UnsafeMutableRawPointer(object),
                sourceLocation: sourceLocation
            )
            #expect(
                unsafe record.surface == UnsafeMutableRawPointer(surface),
                sourceLocation: sourceLocation
            )
        }
    }
}
