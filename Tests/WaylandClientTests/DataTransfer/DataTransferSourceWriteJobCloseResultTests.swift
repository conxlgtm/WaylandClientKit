import Foundation
import Glibc
import Testing

@testable import WaylandClient

@Suite
struct DataTransferSourceWriteJobCloseResultTests {
    @Test
    func closeResultThrowsCloseError() {
        #expect(throws: Never.self) {
            try FileDescriptorCloseResult.closed.throwIfFailed()
        }
        #expect(
            throws: DataTransferError.closeFileDescriptor(WaylandSystemErrno(unchecked: EBADF))
        ) {
            try FileDescriptorCloseResult.failed(
                WaylandSystemErrno(unchecked: EBADF)
            ).throwIfFailed()
        }
    }

    @Test
    func closeResultNormalizesMissingErrnoToFallback() {
        #expect(
            FileDescriptorCloseResult.posixReturn(-1, errno: 0)
                == .failed(WaylandSystemErrno(unchecked: EIO))
        )
        #expect(
            FileDescriptorCloseResult.posixReturn(-1, errno: EBADF)
                == .failed(WaylandSystemErrno(unchecked: EBADF))
        )
    }

    @Test
    func systemErrnoCapturesPositiveErrnoOrFallback() {
        #expect(
            WaylandSystemErrno(capturingPOSIXErrno: EBADF, fallback: EIO)
                == WaylandSystemErrno(unchecked: EBADF)
        )
        #expect(
            WaylandSystemErrno(capturingPOSIXErrno: 0, fallback: EIO)
                == WaylandSystemErrno(unchecked: EIO)
        )
    }

    @Test
    func sourceWriteJobCloseNegativeReturnReportsCloseError() {
        let job = DataTransferSourceWriteJob(
            sourceID: DataSourceID(rawValue: 21),
            mimeType: .plainText,
            descriptor: 201,
            data: Data(),
            prepareDescriptorForWriting: { descriptor in
                #expect(descriptor == 201)
            },
            writeDescriptor: { _, bytes in bytes.count },
            closeDescriptor: { _ in .posixReturn(-1, errno: EIO) }
        )

        #expect(
            job.write()
                == .failed(
                    sourceID: DataSourceID(rawValue: 21),
                    mimeType: .plainText,
                    error: .closeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
                )
        )
    }
}
