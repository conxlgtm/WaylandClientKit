import Foundation
import Glibc
import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct DataTransferDomainTypesTests {
    @Test
    func mimeTypeRejectsMalformedValues() {
        #expect(throws: DataTransferError.invalidMIMEType("")) {
            _ = try MIMEType("")
        }

        #expect(throws: DataTransferError.invalidMIMEType("text/plain\0hidden")) {
            _ = try MIMEType("text/plain\0hidden")
        }

        #expect(throws: DataTransferError.invalidMIMEType(" text/plain ")) {
            _ = try MIMEType(" text/plain ")
        }

        #expect(throws: DataTransferError.invalidMIMEType("text/")) {
            _ = try MIMEType("text/")
        }

        #expect(throws: DataTransferError.invalidMIMEType("text/plain\nbad")) {
            _ = try MIMEType("text/plain\nbad")
        }

        #expect(MIMEType(rawValue: "") == nil)
        #expect(MIMEType(rawValue: "text/plain\0hidden") == nil)
        #expect(MIMEType(rawValue: "text/") == nil)
    }

    @Test
    func mimeTypePreservesExactValidOfferedStringAndConstants() throws {
        let mimeType = try MIMEType("application/x-swiftwayland-test")
        let parameterized = try MIMEType("text/plain;charset=utf-8")

        #expect(mimeType.rawValue == "application/x-swiftwayland-test")
        #expect(mimeType.description == "application/x-swiftwayland-test")
        #expect(parameterized.rawValue == "text/plain;charset=utf-8")
        #expect(MIMEType.plainText.rawValue == "text/plain")
        #expect(MIMEType.plainTextUTF8.rawValue == "text/plain;charset=utf-8")
        #expect(MIMEType.uriList.rawValue == "text/uri-list")
    }

    @Test
    func clipboardSourceConfigurationRequiresPayloadsWithUniqueMimeTypes() throws {
        #expect(throws: DataTransferError.emptyDataSource) {
            _ = try ClipboardSourceConfiguration(payloads: [])
        }

        #expect(throws: DataTransferError.duplicateMIMEType(.plainText)) {
            _ = try ClipboardSourceConfiguration(
                payloads: [
                    ClipboardSourcePayload(
                        mimeType: .plainText,
                        data: Data("one".utf8)
                    ),
                    ClipboardSourcePayload(
                        mimeType: .plainText,
                        data: Data("two".utf8)
                    ),
                ]
            )
        }
    }

    @Test
    func clipboardSourceConfigurationPreservesPayloadOrderAndProvidesDataByMimeType() throws {
        let configuration = try ClipboardSourceConfiguration(
            payloads: [
                ClipboardSourcePayload(
                    mimeType: .plainTextUTF8,
                    data: Data("hello".utf8)
                ),
                ClipboardSourcePayload(
                    mimeType: .uriList,
                    data: Data("file:///tmp/example\n".utf8)
                ),
            ]
        )

        #expect(configuration.mimeTypes == [.plainTextUTF8, .uriList])
        #expect(configuration.payloadSet.data(for: .plainTextUTF8) == Data("hello".utf8))
        #expect(
            configuration.payloadSet.data(for: .uriList)
                == Data("file:///tmp/example\n".utf8)
        )
        #expect(configuration.payloadSet.data(for: .plainText) == nil)
    }

    @Test
    func byteCountRejectsNegativeValuesAndScalesUnits() throws {
        #expect(throws: DataTransferError.negativeByteCount(-1)) {
            _ = try ByteCount(-1)
        }

        #expect(try ByteCount.bytes(0).rawValue == 0)
        #expect(try ByteCount.kilobytes(2).rawValue == 2_048)
        #expect(try ByteCount.megabytes(3).rawValue == 3 * 1_024 * 1_024)
        #expect(ByteCount.defaultTransferReadLimit.rawValue == 16 * 1_024 * 1_024)
    }

    @Test
    func byteCountScalingReportsOverflow() {
        #expect(
            throws: DataTransferError.byteCountOverflow(
                value: Int.max,
                multiplier: 1_024 * 1_024
            )
        ) {
            _ = try ByteCount.megabytes(Int.max)
        }
    }
}

@Suite
struct OwnedFileDescriptorReadTests {
    @Test
    func ownedFileDescriptorRejectsInvalidDescriptor() {
        #expect(throws: DataTransferError.invalidFileDescriptor(-1)) {
            _ = try OwnedFileDescriptor(adopting: -1)
        }
    }

    @Test
    func ownedFileDescriptorCloseIsIdempotentAfterSuccess() throws {
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(adopting: 42) { descriptor in
            closedDescriptors.withLock { $0.append(descriptor) }
            return 0
        }

        let initialRawValue = descriptor.rawValue
        let initiallyClosed = descriptor.isClosed

        #expect(initialRawValue == 42)
        #expect(!initiallyClosed)

        try descriptor.close()
        try descriptor.close()

        let closedAfterClose = descriptor.isClosed
        let descriptionAfterClose = descriptor.description

        #expect(closedAfterClose)
        #expect(descriptionAfterClose == "closed file descriptor")
        #expect(closedDescriptors.withLock { $0 } == [42])
    }

    @Test
    func ownedFileDescriptorDeinitClosesOpenDescriptor() throws {
        let closedDescriptors = Mutex<[Int32]>([])

        do {
            let descriptor = try OwnedFileDescriptor(adopting: 7) { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }

            #expect(descriptor.rawValue == 7)
        }

        #expect(closedDescriptors.withLock { $0 } == [7])
    }

    @Test
    func ownedFileDescriptorReleaseTransfersWithoutClosing() throws {
        let closedDescriptors = Mutex<[Int32]>([])

        do {
            var descriptor = try OwnedFileDescriptor(adopting: 99) { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }

            let releasedDescriptor = descriptor.releaseRawValue()
            let closedAfterRelease = descriptor.isClosed

            #expect(releasedDescriptor == 99)
            #expect(closedAfterRelease)
        }

        #expect(closedDescriptors.withLock { $0.isEmpty })
    }

    @Test
    func ownedFileDescriptorCloseFailureReportsErrnoAndConsumesDescriptor() throws {
        let closeAttempts = Mutex<[Int32]>([])

        do {
            var descriptor = try OwnedFileDescriptor(adopting: 12) { descriptor in
                closeAttempts.withLock { $0.append(descriptor) }
                return 5
            }

            #expect(
                throws: DataTransferError.closeFileDescriptor(
                    WaylandSystemErrno(unchecked: 5)
                )
            ) {
                try descriptor.close()
            }

            let closedAfterFailure = descriptor.isClosed

            #expect(closedAfterFailure)
        }

        #expect(closeAttempts.withLock { $0 } == [12])
    }

    @Test
    func ownedFileDescriptorReadDataClosesDescriptorOnSuccess() throws {
        let readState = Mutex(
            ReadState(chunks: [Array("hello".utf8), []])
        )
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 21,
            readDescriptor: { _, maximumByteCount in
                readState.withLock { state in
                    state.maximumByteCounts.append(maximumByteCount)
                    return state.chunks.removeFirst()
                }
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        let data = try descriptor.readData(limit: try ByteCount.bytes(5))
        let descriptorIsClosed = descriptor.isClosed

        #expect(data == Data("hello".utf8))
        #expect(descriptorIsClosed)
        #expect(readState.withLock { $0.maximumByteCounts } == [6, 1])
        #expect(closedDescriptors.withLock { $0 } == [21])
    }

    @Test
    func ownedFileDescriptorReadDataClosesDescriptorOnReadFailure() throws {
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 22,
            readDescriptor: { _, _ in
                throw DataTransferError.readFileDescriptor(
                    WaylandSystemErrno(unchecked: 5)
                )
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        #expect(
            throws: DataTransferError.readFileDescriptor(
                WaylandSystemErrno(unchecked: 5)
            )
        ) {
            _ = try descriptor.readData(limit: try ByteCount.bytes(5))
        }
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closedDescriptors.withLock { $0 } == [22])
    }

    @Test
    func ownedFileDescriptorReadDataClosesDescriptorWhenTransferExceedsLimit() throws {
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 23,
            readDescriptor: { _, _ in
                Array("toolarge".utf8)
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        #expect(throws: DataTransferError.transferTooLarge(limit: try ByteCount.bytes(3))) {
            _ = try descriptor.readData(limit: try ByteCount.bytes(3))
        }
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closedDescriptors.withLock { $0 } == [23])
    }

    @Test
    func ownedFileDescriptorReadDataReportsCloseFailureAfterSuccess() throws {
        var descriptor = try OwnedFileDescriptor(
            adopting: 24,
            readDescriptor: { _, _ in [] },
            closeDescriptor: { _ in 9 }
        )

        #expect(
            throws: DataTransferError.closeFileDescriptor(
                WaylandSystemErrno(unchecked: 9)
            )
        ) {
            _ = try descriptor.readData(limit: try ByteCount.bytes(3))
        }

        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
    }

    @Test
    func ownedFileDescriptorReadDataPreservesReadFailureWhenCloseFails() throws {
        let closeAttempts = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 25,
            readDescriptor: { _, _ in
                throw DataTransferError.readFileDescriptor(
                    WaylandSystemErrno(unchecked: 5)
                )
            },
            closeDescriptor: { descriptor in
                closeAttempts.withLock { $0.append(descriptor) }
                return 9
            }
        )

        #expect(
            throws: DataTransferError.readFileDescriptor(
                WaylandSystemErrno(unchecked: 5)
            )
        ) {
            _ = try descriptor.readData(limit: try ByteCount.bytes(3))
        }

        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closeAttempts.withLock { $0 } == [25])
    }
}

@Suite
struct OwnedFileDescriptorWriteTests {
    @Test
    func ownedFileDescriptorWriteDataWritesAllBytesAndClosesDescriptor() throws {
        let writeState = Mutex(WriteState(maximumWriteByteCount: 2))
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 31,
            writeDescriptor: { _, bytes in
                writeState.withLock { state in
                    state.writeAttempts.append(Array(bytes))
                    return min(state.maximumWriteByteCount, bytes.count)
                }
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        try descriptor.writeData(Data("hello".utf8))
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(
            writeState.withLock { $0.writeAttempts }
                == [
                    Array("hello".utf8),
                    Array("llo".utf8),
                    Array("o".utf8),
                ]
        )
        #expect(closedDescriptors.withLock { $0 } == [31])
    }

    @Test
    func ownedFileDescriptorWriteDataClosesDescriptorOnWriteFailure() throws {
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 32,
            writeDescriptor: { _, _ in
                throw DataTransferError.writeFileDescriptor(
                    WaylandSystemErrno(unchecked: 5)
                )
            },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        #expect(
            throws: DataTransferError.writeFileDescriptor(
                WaylandSystemErrno(unchecked: 5)
            )
        ) {
            try descriptor.writeData(Data("hello".utf8))
        }
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closedDescriptors.withLock { $0 } == [32])
    }

    @Test
    func ownedFileDescriptorWriteDataTreatsZeroByteWriteAsFailure() throws {
        let closedDescriptors = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 33,
            writeDescriptor: { _, _ in 0 },
            closeDescriptor: { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        #expect(
            throws: DataTransferError.writeFileDescriptor(
                WaylandSystemErrno(unchecked: EIO)
            )
        ) {
            try descriptor.writeData(Data("hello".utf8))
        }
        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closedDescriptors.withLock { $0 } == [33])
    }

    @Test
    func ownedFileDescriptorWriteDataReportsCloseFailureAfterSuccess() throws {
        var descriptor = try OwnedFileDescriptor(
            adopting: 34,
            writeDescriptor: { _, bytes in bytes.count },
            closeDescriptor: { _ in 9 }
        )

        #expect(
            throws: DataTransferError.closeFileDescriptor(
                WaylandSystemErrno(unchecked: 9)
            )
        ) {
            try descriptor.writeData(Data("hello".utf8))
        }

        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
    }

    @Test
    func ownedFileDescriptorWriteDataPreservesWriteFailureWhenCloseFails() throws {
        let closeAttempts = Mutex<[Int32]>([])
        var descriptor = try OwnedFileDescriptor(
            adopting: 35,
            writeDescriptor: { _, _ in
                throw DataTransferError.writeFileDescriptor(
                    WaylandSystemErrno(unchecked: 5)
                )
            },
            closeDescriptor: { descriptor in
                closeAttempts.withLock { $0.append(descriptor) }
                return 9
            }
        )

        #expect(
            throws: DataTransferError.writeFileDescriptor(
                WaylandSystemErrno(unchecked: 5)
            )
        ) {
            try descriptor.writeData(Data("hello".utf8))
        }

        let descriptorIsClosed = descriptor.isClosed

        #expect(descriptorIsClosed)
        #expect(closeAttempts.withLock { $0 } == [35])
    }
}

private struct ReadState {
    var chunks: [[UInt8]]
    var maximumByteCounts: [Int] = []
}

private struct WriteState {
    var maximumWriteByteCount: Int
    var writeAttempts: [[UInt8]] = []
}
