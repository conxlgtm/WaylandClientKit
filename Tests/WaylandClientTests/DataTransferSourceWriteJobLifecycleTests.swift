import Foundation
import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct DataTransferSourceWriteJobLifecycleTests {
    @Test
    func sourceWriteJobDeinitClosesUnconsumedDescriptor() {
        let closedDescriptors = DescriptorCloseRecorder()

        do {
            _ = makeJob(descriptor: 41, closedDescriptors: closedDescriptors)
        }

        #expect(closedDescriptors.descriptors == [41])
    }

    @Test
    func deinitAfterWriteDoesNotCloseAgain() {
        let closedDescriptors = DescriptorCloseRecorder()

        do {
            let job = makeJob(descriptor: 42, closedDescriptors: closedDescriptors)
            #expect(
                job.write()
                    == DataTransferSourceWriteResult.succeeded(
                        sourceID: DataSourceID(rawValue: 1),
                        mimeType: MIMEType.plainText
                    )
            )
        }

        #expect(closedDescriptors.descriptors == [42])
    }

    @Test
    func deinitAfterCancelDoesNotCloseAgain() {
        let closedDescriptors = DescriptorCloseRecorder()

        do {
            let job = makeJob(descriptor: 43, closedDescriptors: closedDescriptors)
            #expect(
                job.closeAsCancelled()
                    == DataTransferSourceWriteResult.failed(
                        sourceID: DataSourceID(rawValue: 1),
                        mimeType: MIMEType.plainText,
                        error: DataTransferError.cancelled
                    )
            )
        }

        #expect(closedDescriptors.descriptors == [43])
    }

    private func makeJob(
        descriptor: Int32,
        closedDescriptors: DescriptorCloseRecorder
    ) -> DataTransferSourceWriteJob {
        DataTransferSourceWriteJob(
            sourceID: DataSourceID(rawValue: 1),
            mimeType: .plainText,
            descriptor: descriptor,
            data: Data()
        ) { descriptor in
            closedDescriptors.record(descriptor)
            return 0
        }
    }
}

private final class DescriptorCloseRecorder: Sendable {
    private let storage = Mutex<[Int32]>([])

    var descriptors: [Int32] {
        storage.withLock { $0 }
    }

    func record(_ descriptor: Int32) {
        storage.withLock { $0.append(descriptor) }
    }
}
