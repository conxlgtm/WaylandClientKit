import CWaylandProtocols
import Foundation
import Testing
import WaylandTestSupport

@testable import WaylandClient

@Suite(
    .enabled(
        if: DragSourceRequestTestEnvironment.isEnabled,
        "Set WAYLAND_DISPLAY and SWIFT_WAYLAND_ENABLE_DND_SOURCE_REQUEST_TESTS=1"
    ),
    .serialized
)
struct WindowDragSourcePublicRequestTests {
    @Test
    func startDragSendsSourceActionsAndStartDragRequest() async throws {
        try await withDragSourceConnection { display, window in
            guard let seat = try await display.firstRawSeatForTesting() else {
                Issue.record(
                    "Skipping drag source request test: compositor advertised no seats.",
                    severity: .warning
                )
                return
            }
            let originPointer = try await requireSurfacePointer(in: display, for: window)
            let configuration = try DragSourceConfiguration(
                payloads: [
                    DataTransferSourcePayload(
                        mimeType: .plainText,
                        data: Data("drag text".utf8)
                    )
                ],
                actions: [.copy, .move]
            )

            let record = try await recordDataRequest {
                _ = try await window.startDrag(
                    source: configuration,
                    seatID: seat.id,
                    serial: InputSerial(rawValue: 77)
                )
            }

            #expect(record.callCount == 3)
            #expect(record.kind == SWL_TEST_DATA_DEVICE_START_DRAG)
            #expect(record.sourceAddress != nil)
            #expect(record.originAddress == originPointer)
            #expect(record.iconAddress == nil)
            #expect(record.serial == 77)
        }
    }
}

private func withDragSourceConnection(
    _ body: @Sendable (WaylandDisplay, Window) async throws -> Void
) async throws {
    try await WaylandDisplay.withConnection(
        cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
        discoveryTimeoutMilliseconds: 5_000
    ) { display in
        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: "SwiftWayland Drag Source Test",
                appID: "swift-wayland-drag-source-test",
                initialWidth: 160,
                initialHeight: 120,
                closeRequestPolicy: .requestOnly,
                decorationPreference: .preferServerSide
            )
        )

        try await body(display, window)
    }
}

private func requireSurfacePointer(
    in display: WaylandDisplay,
    for window: Window
) async throws -> UInt {
    guard
        let pointer = try await display.rawSurfacePointerAddressForTesting(window.id)
    else {
        Issue.record("Expected a live wl_surface for \(window.id).")
        throw DragSourceRequestTestError.missingSurface
    }

    return pointer
}

private func recordDataRequest(
    _ request: @Sendable () async throws -> Void
) async throws -> RecordedDataRequest {
    try await DataRequestRecordingGate.withExclusiveRecording {
        swl_test_data_request_recording_begin()
        defer {
            swl_test_data_request_recording_end()
        }

        try await request()
        return unsafe RecordedDataRequest(swl_test_data_request_record())
    }
}

private struct RecordedDataRequest: Sendable {
    let callCount: Int32
    let kind: swl_test_data_request_kind
    let sourceAddress: UInt?
    let originAddress: UInt?
    let iconAddress: UInt?
    let serial: UInt32

    init(_ record: swl_test_data_request_record) {
        unsafe callCount = record.call_count
        unsafe kind = record.kind
        unsafe sourceAddress = Self.pointerAddress(record.source)
        unsafe originAddress = Self.pointerAddress(record.origin)
        unsafe iconAddress = Self.pointerAddress(record.icon)
        unsafe serial = record.serial
    }

    private static func pointerAddress(_ pointer: UnsafeMutableRawPointer?) -> UInt? {
        unsafe pointer.map { UInt(bitPattern: $0) }
    }
}

private enum DragSourceRequestTestError: Error {
    case missingSurface
}

private enum DragSourceRequestTestEnvironment {
    static var isEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment

        return environment["WAYLAND_DISPLAY"]?.isEmpty == false
            && environment["SWIFT_WAYLAND_ENABLE_DND_SOURCE_REQUEST_TESTS"] == "1"
    }
}
