import Foundation
import Glibc
import Synchronization
import Testing

@testable import WaylandClient

@Suite(.timeLimit(.minutes(1)))
struct ClipboardOfferReadTests {  // swiftlint:disable:this type_body_length
    @Test
    func clipboardOfferReadReturnsDataAfterPeerWritesAndCloses() async throws {
        let descriptors = try makePipeDescriptors()
        let payload = Array("hello".utf8)
        try writeAll(payload, to: descriptors.writeEnd)
        Glibc.close(descriptors.writeEnd)

        var descriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)
        let data = try await descriptor.readData(
            limit: try ByteCount.bytes(32),
            timeout: .seconds(1)
        )
        let descriptorIsClosed = descriptor.isClosed

        #expect(data == Data(payload))
        #expect(descriptorIsClosed)
    }

    @Test
    func clipboardOfferReadRetriesTemporaryUnavailabilityThenReturnsData() async throws {
        let readSteps = Mutex<[ClipboardReadStep]>([
            .temporaryUnavailable,
            .bytes(Array("hello".utf8)),
            .eof,
        ])
        let closedDescriptors = Mutex<[Int32]>([])
        let requestedByteCounts = Mutex<[Int]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 40,
            readDescriptor: { descriptor, maximumByteCount in
                #expect(descriptor == 40)
                requestedByteCounts.withLock { $0.append(maximumByteCount) }

                let nextStep = readSteps.withLock { steps in
                    steps.isEmpty ? .eof : steps.removeFirst()
                }

                switch nextStep {
                case .temporaryUnavailable:
                    throw DataTransferError.readFileDescriptor(
                        WaylandSystemErrno(unchecked: EAGAIN)
                    )
                case .bytes(let bytes):
                    return bytes
                case .eof:
                    return []
                }
            },
            prepareReadDescriptor: { descriptor in
                #expect(descriptor == 40)
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        let data = try await descriptor.readData(
            limit: try ByteCount.bytes(32),
            timeout: .seconds(1)
        )
        let descriptorIsClosed = descriptor.isClosed

        #expect(data == Data("hello".utf8))
        #expect(descriptorIsClosed)
        #expect(closedDescriptors.withLock { $0 } == [40])
        #expect(requestedByteCounts.withLock { $0.count } == 3)
    }

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
    func clipboardOfferReadTimesOutWhenPeerKeepsDescriptorOpenAfterData() async throws {
        let closedDescriptors = Mutex<[Int32]>([])
        let didReturnData = Mutex(false)
        var descriptor = try OwnedFileDescriptor(
            adopting: 44,
            readDescriptor: { _, _ in
                try didReturnData.withLock { hasReturnedData in
                    guard hasReturnedData else {
                        hasReturnedData = true
                        return Array("x".utf8)
                    }

                    throw DataTransferError.readFileDescriptor(
                        WaylandSystemErrno(unchecked: EAGAIN)
                    )
                }
            },
            prepareReadDescriptor: { descriptor in
                #expect(descriptor == 44)
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        await expectDataTransferError(.transferTimedOut) {
            _ = try await descriptor.readData(
                limit: try ByteCount.bytes(32),
                timeout: .milliseconds(5)
            )
        }
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closedDescriptors.withLock { $0 } == [44])
    }

    @Test
    func clipboardOfferReadClosesDescriptorWhenPrepareReadFails() async throws {
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 45,
            readDescriptor: { _, _ in
                Issue.record("Read should not run after prepare failure.")
                return []
            },
            prepareReadDescriptor: { descriptor in
                #expect(descriptor == 45)
                throw DataTransferError.readFileDescriptor(
                    WaylandSystemErrno(unchecked: EIO)
                )
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        await expectDataTransferError(
            .readFileDescriptor(WaylandSystemErrno(unchecked: EIO))
        ) {
            _ = try await descriptor.readData(
                limit: try ByteCount.bytes(32),
                timeout: .seconds(1)
            )
        }
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closedDescriptors.withLock { $0 } == [45])
    }

    @Test
    func clipboardOfferReadReportsCloseFailureAfterSuccess() async throws {
        var descriptor = try OwnedFileDescriptor(
            adopting: 46,
            readDescriptor: { _, _ in [] },
            prepareReadDescriptor: { descriptor in
                #expect(descriptor == 46)
            },
            closeDescriptor: { descriptor in
                #expect(descriptor == 46)
                return EIO
            }
        )

        await expectDataTransferError(
            .closeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
        ) {
            _ = try await descriptor.readData(
                limit: try ByteCount.bytes(32),
                timeout: .seconds(1)
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

            try probe.waitForReadAttempt()
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

private func makePipeDescriptors() throws -> (readEnd: Int32, writeEnd: Int32) {
    var descriptors = [Int32](repeating: -1, count: 2)
    let result = unsafe descriptors.withUnsafeMutableBufferPointer { buffer in
        unsafe Glibc.pipe(buffer.baseAddress)
    }
    guard result == 0 else {
        throw DataTransferError.createPipe(
            WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
        )
    }

    return (readEnd: descriptors[0], writeEnd: descriptors[1])
}

private func writeAll(_ bytes: [UInt8], to descriptor: Int32) throws {
    var writtenByteCount = 0

    while writtenByteCount < bytes.count {
        let remainingBytes = bytes[writtenByteCount...]
        let result = unsafe remainingBytes.withUnsafeBufferPointer { buffer in
            unsafe Glibc.write(descriptor, buffer.baseAddress, buffer.count)
        }
        guard result > 0 else {
            throw DataTransferError.writeFileDescriptor(
                WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
            )
        }

        writtenByteCount += result
    }
}

private enum ClipboardReadStep: Sendable {
    case temporaryUnavailable
    case bytes([UInt8])
    case eof
}

// SAFETY: Probe state is private and every access is protected by NSCondition or Mutex.
private final class ClipboardReadCancellationProbe: @unchecked Sendable {
    private let condition = NSCondition()
    private var readAttemptCount = 0
    private let closedDescriptorStorage = Mutex<[Int32]>([])

    var closedDescriptors: [Int32] {
        closedDescriptorStorage.withLock { $0 }
    }

    func recordReadAttempt() {
        condition.lock()
        readAttemptCount += 1
        condition.broadcast()
        condition.unlock()
    }

    func recordClosedDescriptor(_ descriptor: Int32) {
        closedDescriptorStorage.withLock { $0.append(descriptor) }
    }

    func waitForReadAttempt() throws {
        condition.lock()
        defer { condition.unlock() }
        guard readAttemptCount == 0 else {
            return
        }

        let deadline = Date().addingTimeInterval(1)
        while readAttemptCount == 0 {
            guard condition.wait(until: deadline) else {
                Issue.record("Timed out waiting for read attempt.")
                return
            }
        }
    }
}
