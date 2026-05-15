extension PrimarySelectionController {
    package func drainSourceSendRequests() -> [DataTransferSourceSendRequest] {
        backend.preconditionIsOwnerThread()
        defer { pendingSourceSendRequests.removeAll(keepingCapacity: true) }
        return pendingSourceSendRequests
    }

    package func drainSourceWriteJobs() throws -> [DataTransferSourceWriteJob] {
        let requests = drainSourceSendRequests()
        var jobs: [DataTransferSourceWriteJob] = []

        for index in requests.indices {
            do {
                jobs.append(try requests[index].makeWriteJob())
            } catch {
                discardSourceWriteJobs(jobs)
                discardRemainingSourceSendRequests(requests[(index + 1)...])
                throw error
            }
        }

        return jobs
    }

    func closeSourceSendDescriptor(_ descriptor: Int32) throws {
        guard descriptor >= 0 else {
            throw DataTransferError.invalidFileDescriptor(descriptor)
        }

        try backend.closeFileDescriptor(descriptor).throwIfFailed()
    }

    package func discardPendingSourceSendRequests(for sourceID: DataSourceID) {
        var remainingRequests: [DataTransferSourceSendRequest] = []
        for request in drainSourceSendRequests() {
            if request.source == .primarySelection(sourceID) {
                do {
                    try request.close()
                } catch {
                    recordCallbackError(
                        error,
                        context: .primarySelectionSource(
                            sourceID.primarySelectionIdentity
                        )
                    )
                }
            } else {
                remainingRequests.append(request)
            }
        }

        pendingSourceSendRequests = remainingRequests
    }

    func discardAllPendingSourceSendRequests() {
        for request in drainSourceSendRequests() {
            do {
                try request.close()
            } catch {
                _ = error
            }
        }
    }

    private func discardSourceWriteJobs(_ jobs: [DataTransferSourceWriteJob]) {
        for job in jobs {
            _ = job.closeAsCancelled()
        }
    }

    private func discardRemainingSourceSendRequests(
        _ requests: ArraySlice<DataTransferSourceSendRequest>
    ) {
        for request in requests {
            do {
                try request.close()
            } catch {
                recordCallbackError(error, context: .sourceWrite(request.source.diagnosticSource))
            }
        }
    }
}
