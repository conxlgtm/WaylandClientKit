import Glibc
import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct DataTransferPipeReceiveTests {
    @Test
    func readEndAdoptionFailureClosesBothRawDescriptors() throws {
        let backend = RecordingReceivePipeBackend(failingAdoptions: [3])
        let descriptors = DataTransferPipeDescriptors(readEnd: 3, writeEnd: 4)

        #expect(throws: DataTransferError.invalidFileDescriptor(3)) {
            _ = try descriptors.adoptReadEnd(using: backend)
        }
        #expect(backend.rawCloseCalls == [3, 4])
        #expect(backend.adoptedCloseCalls.isEmpty)
    }

    @Test
    func writeEndAdoptionFailureClosesRawWriteAndAdoptedRead() throws {
        let backend = RecordingReceivePipeBackend(failingAdoptions: [4])
        let descriptors = DataTransferPipeDescriptors(readEnd: 3, writeEnd: 4)
        var readEnd = try descriptors.adoptReadEnd(using: backend)

        #expect(throws: DataTransferError.invalidFileDescriptor(4)) {
            try descriptors.receive(
                into: RecordingReceiveBinding(),
                mimeType: .plainText,
                readEnd: &readEnd,
                using: backend
            )
        }
        let readEndClosed = readEnd.isClosed
        #expect(backend.rawCloseCalls == [4])
        #expect(backend.adoptedCloseCalls == [3])
        #expect(readEndClosed)
    }

    @Test
    func successfulReceiveClosesWriteEndAndLeavesReadEndOpen() throws {
        let backend = RecordingReceivePipeBackend()
        let binding = RecordingReceiveBinding()
        let descriptors = DataTransferPipeDescriptors(readEnd: 3, writeEnd: 4)
        var readEnd = try descriptors.adoptReadEnd(using: backend)

        try descriptors.receive(
            into: binding,
            mimeType: .plainTextUTF8,
            readEnd: &readEnd,
            using: backend
        )

        #expect(binding.received == [ReceivedDescriptor(mimeType: .plainTextUTF8, fd: 4)])
        let readEndClosed = readEnd.isClosed
        #expect(backend.rawCloseCalls.isEmpty)
        #expect(backend.adoptedCloseCalls == [4])
        #expect(!readEndClosed)
        try readEnd.close()
    }

    @Test
    func writeCloseFailureClosesReadEndAndThrowsCloseError() throws {
        let backend = RecordingReceivePipeBackend(closeFailures: [4: EIO])
        let descriptors = DataTransferPipeDescriptors(readEnd: 3, writeEnd: 4)
        var readEnd = try descriptors.adoptReadEnd(using: backend)

        #expect(throws: DataTransferError.closeFileDescriptor(WaylandSystemErrno(unchecked: EIO))) {
            try descriptors.receive(
                into: RecordingReceiveBinding(),
                mimeType: .plainText,
                readEnd: &readEnd,
                using: backend
            )
        }
        let readEndClosed = readEnd.isClosed
        #expect(backend.rawCloseCalls.isEmpty)
        #expect(backend.adoptedCloseCalls == [4, 3])
        #expect(readEndClosed)
    }
}

private final class RecordingReceivePipeBackend: DataTransferReceivePipeBackend, Sendable {
    private let failingAdoptions: Set<Int32>
    private let closeFailures: [Int32: Int32]
    private let rawCloseCallStorage = Mutex<[Int32]>([])
    private let adoptedCloseCallStorage = Mutex<[Int32]>([])

    var rawCloseCalls: [Int32] {
        rawCloseCallStorage.withLock { $0 }
    }

    var adoptedCloseCalls: [Int32] {
        adoptedCloseCallStorage.withLock { $0 }
    }

    init(failingAdoptions: Set<Int32> = [], closeFailures: [Int32: Int32] = [:]) {
        self.failingAdoptions = failingAdoptions
        self.closeFailures = closeFailures
    }

    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor {
        if failingAdoptions.contains(descriptor) {
            throw DataTransferError.invalidFileDescriptor(descriptor)
        }

        return try OwnedFileDescriptor(adopting: descriptor) { descriptor in
            self.recordAdoptedClose(descriptor)
            return self.closeFailures[descriptor] ?? 0
        }
    }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult {
        rawCloseCallStorage.withLock { $0.append(descriptor) }
        return .closed
    }

    private func recordAdoptedClose(_ descriptor: Int32) {
        adoptedCloseCallStorage.withLock { $0.append(descriptor) }
    }
}

private struct ReceivedDescriptor: Equatable {
    let mimeType: MIMEType
    let fd: Int32
}

private final class RecordingReceiveBinding: DataTransferReceiveBinding {
    private(set) var received: [ReceivedDescriptor] = []

    func receive(mimeType: MIMEType, fd: Int32) {
        received.append(ReceivedDescriptor(mimeType: mimeType, fd: fd))
    }
}
