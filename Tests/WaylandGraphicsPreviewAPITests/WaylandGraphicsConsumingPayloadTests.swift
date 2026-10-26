import CWaylandProtocols
import Foundation
import Glibc
import Synchronization
import Testing
import WaylandClient
import WaylandGraphicsPreview
import WaylandRuntime

@testable import WaylandRaw

@Suite
struct WaylandGraphicsConsumingPayloadTests {
    @Test(
        .enabled(
            if: ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"]?.isEmpty == false
                && ProcessInfo.processInfo.environment[
                    "WAYLAND_CLIENT_KIT_ENABLE_CONNECTION_LIFETIME_TESTS"] == "1",
            "Set WAYLAND_DISPLAY and WAYLAND_CLIENT_KIT_ENABLE_CONNECTION_LIFETIME_TESTS=1"
        ),
        .timeLimit(.minutes(1))
    )
    func closedDisplayDisposesUntouchedPayload() async throws {
        let probe = try PlaneDescriptorProbe(count: 4)
        defer { probe.closeReaders() }
        try await WaylandDisplay.withConnection(applicationID: "org.waylandclientkit.payload-test")
        { display in
            await display.close()
            do {
                let payload = try probe.descriptor()
                _ = try await display.withGraphicsPreviewLinuxDmabuf(payload) { value, _, _ in
                    _ = consume value
                    Issue.record("closed display entered the native import scope")
                    return false
                }
                Issue.record("closed display accepted a graphics payload")
            } catch ClientError.display(.closed) {
                #expect(probe.ownerCloseCounts == [1, 1, 1, 1])
            }
        }
        try probe.expectEOF()
    }

    @Test(arguments: 1...4)
    func nativeImportTransfersEveryPlaneOnOwnerThread(planeCount: Int) async throws {
        let probe = try PlaneDescriptorProbe(count: planeCount)
        defer { probe.closeReaders() }
        let executor = try WaylandThreadExecutor()
        let owner = NativeImportOwner(executor: executor)
        let result = try await owner.run(
            probe.descriptor(),
            outcome: .created
        )
        executor.shutdown()

        #expect(result.addedPlanes == Array(0..<planeCount))
        #expect(result.createCount == 1)
        #expect(result.bufferDestroyCount == 1)
        #expect(result.paramsDestroyCount == 1)
        #expect(result.ranOnOwnerThread)
        #expect(probe.ownerCloseCounts == Array(repeating: 0, count: planeCount))
        try probe.expectEOF()
    }

    @Test(arguments: 1...4)
    func failureAfterEveryPartialTransferClosesRemainingPlanes(planeCount: Int) async throws {
        for rejectedPlane in 0..<planeCount {
            let probe = try PlaneDescriptorProbe(count: planeCount)
            defer { probe.closeReaders() }
            let executor = try WaylandThreadExecutor()
            let owner = NativeImportOwner(executor: executor)
            let result = try await owner.rejectPartialTransfer(
                probe.planes(), rejectedPlane: rejectedPlane)
            executor.shutdown()

            #expect(result.addedPlanes == Array(0..<rejectedPlane))
            #expect(result.createCount == 0)
            #expect(result.bufferDestroyCount == 0)
            #expect(result.paramsDestroyCount == 1)
            #expect(result.ranOnOwnerThread)
            #expect(probe.ownerCloseCounts == (0..<planeCount).map { $0 <= rejectedPlane ? 0 : 1 })
            try probe.expectEOF()
        }
    }

    @Test(arguments: 1...4, [NativeImportOutcome.failed, .syncFailure, .paramsFailure])
    func nativeImportFailureDisposesConsumedPayload(
        planeCount: Int,
        outcome: NativeImportOutcome
    ) async throws {
        let probe = try PlaneDescriptorProbe(count: planeCount)
        defer { probe.closeReaders() }
        let executor = try WaylandThreadExecutor()
        let owner = NativeImportOwner(executor: executor)
        let result = try await owner.run(
            probe.descriptor(),
            outcome: outcome,
            expectsFailure: true
        )
        executor.shutdown()

        let reachedParams = outcome != .paramsFailure
        #expect(result.addedPlanes == (reachedParams ? Array(0..<planeCount) : []))
        #expect(result.createCount == (reachedParams ? 1 : 0))
        #expect(result.bufferDestroyCount == 0)
        #expect(result.paramsDestroyCount == (reachedParams ? 1 : 0))
        #expect(
            probe.ownerCloseCounts == Array(repeating: reachedParams ? 0 : 1, count: planeCount))
        try probe.expectEOF()
    }

    @Test
    func nativeParamsValidateAddAndCreateBeforeSendingRequests() async throws {
        let probe = try PlaneDescriptorProbe(count: 2)
        defer { probe.closeReaders() }
        let executor = try WaylandThreadExecutor()
        let owner = NativeImportOwner(executor: executor)
        let result = try await owner.validateParams(
            first: probe.ownedDescriptor(at: 0),
            duplicate: probe.ownedDescriptor(at: 1)
        )
        executor.shutdown()

        #expect(result.addedPlanes == [0])
        #expect(result.createCount == 1)
        #expect(result.paramsDestroyCount == 1)
        #expect(result.ranOnOwnerThread)
        #expect(probe.ownerCloseCounts == [0, 0])
        try probe.expectEOF()
    }

    @Test(arguments: [[UInt32(1), 0], [0, 0], [0, 2]])
    func invalidPlaneOrderDisposesRealDescriptors(indices: [UInt32]) throws {
        let probe = try PlaneDescriptorProbe(count: 2)
        defer { probe.closeReaders() }
        do {
            _ = try WaylandGraphicsExternalBufferDescriptor(
                size: PositivePixelSize(width: 4, height: 4),
                format: .xrgb8888,
                modifier: .linear,
                plane0: WaylandGraphicsExternalBufferPlane(
                    fileDescriptor: probe.ownedDescriptor(at: 0), offset: 0, stride: 16,
                    planeIndex: indices[0]
                ),
                plane1: WaylandGraphicsExternalBufferPlane(
                    fileDescriptor: probe.ownedDescriptor(at: 1), offset: 64, stride: 16,
                    planeIndex: indices[1]
                )
            )
            Issue.record("invalid plane ordering accepted")
        } catch WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor) {
            #expect(probe.ownerCloseCounts == [1, 1])
        }
        try probe.expectEOF()
    }
}

enum NativeImportOutcome: Equatable, Sendable {
    case created
    case failed
    case syncFailure
    case paramsFailure
}

struct NativeImportResult: Sendable {
    var addedPlanes: [Int] = []
    var createCount = 0
    var bufferDestroyCount = 0
    var paramsDestroyCount = 0
    var ranOnOwnerThread = false
    var nativeDestructionOnOwnerThread = false
}

private enum NativeImportTestError: Error {
    case syncFailure
}

actor NativeImportOwner {
    private let executor: WaylandThreadExecutor
    private var nativeTransport: NativeDmabufTransport?
    private var nativeResult = NativeImportResult()
    private var nativeBufferID: UInt32?

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe executor.asUnownedSerialExecutor()
    }

    init(executor: WaylandThreadExecutor) {
        self.executor = executor
    }

    func isOnOwnerThread() -> Bool {
        executor.isOwnerThread
    }

    func importNativeBuffer(
        _ descriptor: consuming WaylandGraphicsExternalBufferDescriptor
    ) throws -> RawLinuxDmabufBuffer {
        let transport = try NativeDmabufTransport(version: 1)
        nativeTransport = transport
        do {
            let buffer = try descriptor.importBuffer(
                using: transport.linuxDmabuf,
                timeoutMilliseconds: 1_000
            ) { _ in
                try transport.drainRequests(into: &nativeResult)
                try transport.deliver(created: true)
            }
            nativeBufferID = unsafe wl_proxy_get_id(buffer.pointer)
            #if SWL_ENABLE_TESTING
                unsafe swl_test_buffer_destroy_thread_recording_begin(buffer.pointer)
            #endif
            return buffer
        } catch {
            transport.close()
            nativeTransport = nil
            throw error
        }
    }

    func finishNativeSession() throws -> NativeImportResult {
        let transport = try #require(nativeTransport)
        defer {
            transport.close()
            nativeTransport = nil
            nativeBufferID = nil
        }
        try transport.drainRequests(into: &nativeResult, bufferID: nativeBufferID)
        #if SWL_ENABLE_TESTING
            let destructionThread = swl_test_buffer_destroy_thread()
            nativeResult.nativeDestructionOnOwnerThread = destructionThread == pthread_self()
        #endif
        return nativeResult
    }

    func validateParams(
        first: consuming OwnedFileDescriptor,
        duplicate: consuming OwnedFileDescriptor
    ) throws -> NativeImportResult {
        let transport = try NativeDmabufTransport(version: 1)
        defer { transport.close() }
        var result = NativeImportResult(ranOnOwnerThread: executor.isOwnerThread)
        let params = try transport.linuxDmabuf.createBufferParams { _ in
            Issue.record("validation test unexpectedly received an event")
        } onFailure: { error in
            Issue.record("validation test failed: \(error)")
        }
        var first = first
        var duplicate = duplicate
        var plane = try RawLinuxDmabufPlaneFileDescriptor(adopting: first.releaseRawValue())
        var rejectedPlane = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: duplicate.releaseRawValue())
        try params.addPlane(
            fileDescriptor: &plane, planeIndex: 0, offset: 0, stride: 16, modifier: 0
        )
        #expect(throws: RuntimeError.invalidArgument("duplicate linux-dmabuf plane index 0")) {
            try params.addPlane(
                fileDescriptor: &rejectedPlane, planeIndex: 0, offset: 0, stride: 16, modifier: 0
            )
        }
        #expect(throws: RuntimeError.invalidArgument("dmabuf buffer dimensions")) {
            try params.create(width: 0, height: 4, format: 875_713_112)
        }
        try params.create(width: 4, height: 4, format: 875_713_112)
        #expect(throws: RuntimeError.invalidArgument("repeat linux-dmabuf buffer create request")) {
            try params.create(width: 4, height: 4, format: 875_713_112)
        }
        #expect(executor.isOwnerThread)
        params.destroy()
        params.destroy()
        try transport.drainRequests(into: &result)
        return result
    }

    func rejectPartialTransfer(
        _ payload: consuming WaylandGraphicsExternalBufferPlanes, rejectedPlane: Int
    ) throws -> NativeImportResult {
        let transport = try NativeDmabufTransport(version: 1)
        defer { transport.close() }
        var result = NativeImportResult(ranOnOwnerThread: executor.isOwnerThread)
        let params = try transport.linuxDmabuf.createBufferParams { _ in
            Issue.record("partial transfer unexpectedly received an event")
        } onFailure: { error in
            Issue.record("partial transfer failed: \(error)")
        }
        var planes = payload
        do {
            try planes.withMutablePlanes { plane in
                if plane.planeIndex == rejectedPlane { params.destroy() }
                var rawPlane = try RawLinuxDmabufPlaneFileDescriptor(
                    adopting: plane.fileDescriptor.releaseRawValue())
                try params.addPlane(
                    fileDescriptor: &rawPlane,
                    planeIndex: UInt32(plane.planeIndex),
                    offset: plane.offset, stride: plane.stride, modifier: 0)
            }
            Issue.record("destroyed native params accepted another plane")
        } catch is RuntimeError {
            #expect(executor.isOwnerThread)
        }
        params.destroy()
        try transport.drainRequests(into: &result)
        return result
    }

    func run(
        _ descriptor: consuming WaylandGraphicsExternalBufferDescriptor,
        outcome: NativeImportOutcome,
        expectsFailure: Bool = false
    ) throws -> NativeImportResult {
        let transport = try NativeDmabufTransport(version: outcome == .paramsFailure ? 0 : 1)
        defer { transport.close() }
        var result = NativeImportResult(ranOnOwnerThread: executor.isOwnerThread)
        do {
            let buffer = try descriptor.importBuffer(
                using: transport.linuxDmabuf,
                timeoutMilliseconds: 1_000
            ) { _ in
                try transport.drainRequests(into: &result)
                if outcome == .syncFailure {
                    throw NativeImportTestError.syncFailure
                }
                try transport.deliver(created: outcome == .created)
            }
            #expect(!expectsFailure)
            #expect(executor.isOwnerThread)
            let bufferID = unsafe wl_proxy_get_id(buffer.pointer)
            buffer.destroy()
            buffer.destroy()
            try transport.drainRequests(into: &result, bufferID: bufferID)
        } catch {
            #expect(expectsFailure, "unexpected native import error: \(error)")
            try transport.drainRequests(into: &result)
        }
        #expect(executor.isOwnerThread)
        return result
    }
}

// A socket peer accepts real libwayland requests and returns protocol events.
@safe
private final class NativeDmabufTransport {
    private let display: OpaquePointer
    private let registry: OpaquePointer
    private let queue: RawEventQueue
    private let peer: Int32
    private let linuxDmabufID: UInt32
    private var paramsID: UInt32?
    private var isClosed = false
    let linuxDmabuf: RawLinuxDmabuf

    init(version: UInt32) throws {
        var sockets = [Int32](repeating: -1, count: 2)
        let socketResult = sockets.withUnsafeMutableBufferPointer { sockets in
            unsafe Glibc.socketpair(
                AF_UNIX, Int32(SOCK_STREAM.rawValue | SOCK_CLOEXEC.rawValue), 0, sockets.baseAddress
            )
        }
        try #require(socketResult == 0)
        peer = sockets[1]
        guard let connection = unsafe wl_display_connect_to_fd(sockets[0]) else {
            Glibc.close(sockets[0])
            Glibc.close(sockets[1])
            throw NativeImportTestError.syncFailure
        }
        unsafe display = connection
        let queuePointer = try unsafe #require(swl_display_create_event_queue(connection))
        queue = RawEventQueue(opaquePointer: queuePointer)
        let wrapper = try unsafe #require(swl_display_create_wrapper(connection))
        unsafe swl_display_wrapper_set_queue(wrapper, queuePointer)
        unsafe registry = try #require(swl_display_get_registry(wrapper))
        unsafe swl_display_wrapper_destroy(wrapper)
        let dmabuf = try unsafe #require(swl_registry_bind_zwp_linux_dmabuf_v1(registry, 1, 1))
        linuxDmabufID = unsafe wl_proxy_get_id(dmabuf)
        linuxDmabuf = try RawLinuxDmabuf(
            pointer: dmabuf,
            version: RawVersion(version),
            proxyAdoption: RawProxyAdoptionContext(eventQueue: queue)
        )
        let flags = Glibc.fcntl(peer, F_GETFL)
        try #require(flags >= 0)
        try #require(Glibc.fcntl(peer, F_SETFL, flags | O_NONBLOCK) == 0)
    }

    func drainRequests(into result: inout NativeImportResult, bufferID: UInt32? = nil) throws {
        try unsafe #require(wl_display_flush(display) >= 0)
        var storage = [UInt8](repeating: 0, count: 16_384)
        var received: [UInt8] = []
        while true {
            // read discards SCM_RIGHTS attachments, closing the peer's received fds.
            let count = storage.withUnsafeMutableBytes { bytes in
                unsafe Glibc.read(peer, bytes.baseAddress, bytes.count)
            }
            if count < 0 {
                try #require(errno == EAGAIN || errno == EWOULDBLOCK)
                break
            }
            try #require(count > 0)
            received.append(contentsOf: storage.prefix(count))
        }
        try received.withUnsafeBytes { bytes in
            let span = unsafe RawSpan(_unsafeBytes: bytes)
            var offset = 0
            while offset < span.byteCount {
                try #require(span.byteCount - offset >= 8)
                let objectID = span.load(fromByteOffset: offset, as: UInt32.self)
                let header = span.load(fromByteOffset: offset + 4, as: UInt32.self)
                let length = Int(header >> 16)
                let opcode = header & 0xffff
                try #require(length >= 8 && length <= span.byteCount - offset)
                if objectID == linuxDmabufID, opcode == 1 {
                    paramsID = span.load(fromByteOffset: offset + 8, as: UInt32.self)
                } else if objectID == paramsID, opcode == 1 {
                    let index = span.load(fromByteOffset: offset + 8, as: UInt32.self)
                    result.addedPlanes.append(Int(index))
                } else if objectID == paramsID, opcode == 2 {
                    result.createCount += 1
                } else if objectID == bufferID, opcode == 0 {
                    result.bufferDestroyCount += 1
                } else if objectID == paramsID, opcode == 0 {
                    result.paramsDestroyCount += 1
                }
                offset += length
            }
        }
    }

    func deliver(created: Bool) throws {
        let paramsID = try #require(paramsID)
        let words: [UInt32] =
            created
            ? [paramsID, 12 << 16, 0xff00_0000]
            : [paramsID, (8 << 16) | 1]
        let count = words.withUnsafeBytes { bytes in
            unsafe Glibc.write(peer, bytes.baseAddress, bytes.count)
        }
        try #require(count == words.count * MemoryLayout<UInt32>.size)
        try unsafe #require(wl_display_dispatch_queue(display, queue.opaquePointer) >= 0)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        linuxDmabuf.destroy()
        unsafe swl_registry_destroy(registry)
        queue.destroy()
        unsafe wl_display_disconnect(display)
        Glibc.close(peer)
    }
}
