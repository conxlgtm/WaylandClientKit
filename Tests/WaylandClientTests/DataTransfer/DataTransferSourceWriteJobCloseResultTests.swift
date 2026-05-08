import Foundation
import Glibc
import Testing

@testable import WaylandClient

@Suite
struct DataTransferSourceWriteJobCloseResultTests {
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
