import Foundation
import Glibc
import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct ClipboardOfferReadTests {
    @Test
    func clipboardOfferReadTimesOutWhenPeerDoesNotWrite() async throws {
        let descriptors = try makePipeDescriptors()
        defer { Glibc.close(descriptors.writeEnd) }
        var descriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)

        await expectDataTransferError(.transferTimedOut) {
            _ = try await descriptor.readData(
                limit: try ByteCount.bytes(32),
                timeout: .milliseconds(5)
            )
        }
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
    }

    @Test
    func clipboardOfferReadCancellationClosesDescriptor() async throws {
        let probe = ClipboardReadCancellationProbe()

        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                var descriptor = try OwnedFileDescriptor(
                    adopting: 41,
                    readDescriptor: { _, _ in
                        probe.recordReadAttempt()
                        throw DataTransferError.readFileDescriptor(
                            WaylandSystemErrno(unchecked: EAGAIN)
                        )
                    },
                    prepareReadDescriptor: { descriptor in
                        #expect(descriptor == 41)
                    },
                    closeDescriptor: { descriptor in
                        probe.recordClosedDescriptor(descriptor)
                        return 0
                    }
                )

                return try await descriptor.readData(
                    limit: try ByteCount.bytes(32),
                    timeout: .seconds(1)
                )
            }

            try await waitUntil { probe.hasReadAttempt }
            group.cancelAll()

            await expectDataTransferError(.cancelled) {
                _ = try await group.next()
            }
        }

        #expect(probe.closedDescriptors == [41])
    }

    @Test
    func clipboardOfferReadPreservesOriginalReadError() async throws {
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 42,
            readDescriptor: { _, _ in
                throw DataTransferError.readFileDescriptor(
                    WaylandSystemErrno(unchecked: 5)
                )
            },
            prepareReadDescriptor: { descriptor in
                #expect(descriptor == 42)
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        await expectDataTransferError(
            .readFileDescriptor(WaylandSystemErrno(unchecked: 5))
        ) {
            _ = try await descriptor.readData(
                limit: try ByteCount.bytes(32),
                timeout: .seconds(1)
            )
        }
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closedDescriptors.withLock { $0 } == [42])
    }

    @Test
    func clipboardOfferReadClosesDescriptorAfterTransferTooLarge() async throws {
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 43,
            readDescriptor: { _, _ in
                Array("toolarge".utf8)
            },
            prepareReadDescriptor: { descriptor in
                #expect(descriptor == 43)
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        await expectDataTransferError(.transferTooLarge(limit: try ByteCount.bytes(3))) {
            _ = try await descriptor.readData(
                limit: try ByteCount.bytes(3),
                timeout: .seconds(1)
            )
        }
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closedDescriptors.withLock { $0 } == [43])
    }
}

private func expectDataTransferError(
    _ expectedError: DataTransferError,
    _ operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected data transfer error \(expectedError).")
    } catch let error as DataTransferError {
        #expect(error == expectedError)
    } catch {
        Issue.record("Expected data transfer error \(expectedError), got \(error).")
    }
}

private func waitUntil(
    _ condition: () -> Bool
) async throws {
    for _ in 0..<1_000 {
        if condition() {
            return
        }

        try await Task.sleep(for: .milliseconds(1))
    }

    Issue.record("Timed out waiting for condition.")
}

private func makePipeDescriptors() throws -> (readEnd: Int32, writeEnd: Int32) {
    var descriptors = [Int32](repeating: -1, count: 2)
    let result = descriptors.withUnsafeMutableBufferPointer { buffer in
        Glibc.pipe(buffer.baseAddress)
    }
    guard result == 0 else {
        throw DataTransferError.createPipe(
            WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
        )
    }

    return (readEnd: descriptors[0], writeEnd: descriptors[1])
}

private final class ClipboardReadCancellationProbe: Sendable {
    private let readAttempts = Mutex(0)
    private let closedDescriptorStorage = Mutex<[Int32]>([])

    var hasReadAttempt: Bool {
        readAttempts.withLock { $0 > 0 }
    }

    var closedDescriptors: [Int32] {
        closedDescriptorStorage.withLock { $0 }
    }

    func recordReadAttempt() {
        readAttempts.withLock { $0 += 1 }
    }

    func recordClosedDescriptor(_ descriptor: Int32) {
        closedDescriptorStorage.withLock { $0.append(descriptor) }
    }
}
