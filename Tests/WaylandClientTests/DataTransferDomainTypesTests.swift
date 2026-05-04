import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct DataTransferDomainTypesTests {
    @Test
    func mimeTypeRejectsEmptyAndInteriorNULValues() {
        #expect(throws: DataTransferError.invalidMIMEType("")) {
            _ = try MIMEType("")
        }

        #expect(throws: DataTransferError.invalidMIMEType("text/plain\0hidden")) {
            _ = try MIMEType("text/plain\0hidden")
        }

        #expect(MIMEType(rawValue: "") == nil)
        #expect(MIMEType(rawValue: "text/plain\0hidden") == nil)
    }

    @Test
    func mimeTypePreservesExactOfferedStringAndConstants() throws {
        let mimeType = try MIMEType("application/x-swiftwayland-test")

        #expect(mimeType.rawValue == "application/x-swiftwayland-test")
        #expect(mimeType.description == "application/x-swiftwayland-test")
        #expect(MIMEType.plainText.rawValue == "text/plain")
        #expect(MIMEType.plainTextUTF8.rawValue == "text/plain;charset=utf-8")
        #expect(MIMEType.uriList.rawValue == "text/uri-list")
    }

    @Test
    func byteCountRejectsNegativeValuesAndScalesUnits() throws {
        #expect(throws: DataTransferError.negativeByteCount(-1)) {
            _ = try ByteCount(-1)
        }

        #expect(try ByteCount.bytes(0).rawValue == 0)
        #expect(try ByteCount.kilobytes(2).rawValue == 2_048)
        #expect(try ByteCount.megabytes(3).rawValue == 3 * 1_024 * 1_024)
        #expect(ByteCount.defaultClipboardReadLimit.rawValue == 16 * 1_024 * 1_024)
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
    func ownedFileDescriptorCloseFailureReportsErrnoAndKeepsOwnership() throws {
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

            #expect(!closedAfterFailure)
        }

        #expect(closeAttempts.withLock { $0 } == [12, 12])
    }
}
