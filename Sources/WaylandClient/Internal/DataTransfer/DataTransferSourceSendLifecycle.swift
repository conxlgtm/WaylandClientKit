import Glibc

package enum DataTransferSourceSendLifecycle {
    package static func makeWriteJobs(
        from requests: [DataTransferSourceSendRequest],
        recordDiscardError: (DataTransferSourceSendRequest, any Error) -> Void
    ) throws -> [DataTransferSourceWriteJob] {
        var jobs: [DataTransferSourceWriteJob] = []

        for index in requests.indices {
            do {
                jobs.append(try requests[index].makeWriteJob())
            } catch {
                cancelWriteJobs(jobs)
                discardRequests(
                    requests[(index + 1)...],
                    recordError: recordDiscardError
                )
                throw error
            }
        }

        return jobs
    }

    package static func closeCallbackDescriptor(
        _ descriptor: Int32,
        close: (Int32) -> FileDescriptorCloseResult
    ) throws {
        guard descriptor >= 0 else {
            throw DataTransferError.invalidFileDescriptor(descriptor)
        }

        try close(descriptor).throwIfFailed()
    }

    package static func discardRequests<Requests: Sequence>(
        _ requests: Requests,
        recordError: (DataTransferSourceSendRequest, any Error) -> Void
    ) where Requests.Element == DataTransferSourceSendRequest {
        for request in requests {
            do {
                try request.close()
            } catch {
                recordError(request, error)
            }
        }
    }

    package static func cancelWriteJobs(_ jobs: [DataTransferSourceWriteJob]) {
        for job in jobs {
            _ = job.closeAsCancelled()
        }
    }
}
