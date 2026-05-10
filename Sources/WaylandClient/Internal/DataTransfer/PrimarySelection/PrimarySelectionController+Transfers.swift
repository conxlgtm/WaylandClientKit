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

    func adoptReadEnd(
        _ descriptors: DataTransferPipeDescriptors
    ) throws -> OwnedFileDescriptor {
        do {
            return try backend.adoptOwnedFileDescriptor(descriptors.readEnd)
        } catch {
            closePipeDescriptorIfValid(descriptors.readEnd)
            closePipeDescriptorIfValid(descriptors.writeEnd)
            throw error
        }
    }

    func receiveIntoPipe(
        _ binding: any PrimarySelectionOfferBinding,
        mimeType: MIMEType,
        descriptors: DataTransferPipeDescriptors,
        readEnd: inout OwnedFileDescriptor
    ) throws {
        var rawWriteEnd: Int32? = descriptors.writeEnd
        do {
            var writeEnd = try backend.adoptOwnedFileDescriptor(descriptors.writeEnd)
            rawWriteEnd = nil
            binding.receive(mimeType: mimeType, fd: writeEnd.rawValue)
            try writeEnd.close()
        } catch {
            if let rawWriteEnd {
                closePipeDescriptorIfValid(rawWriteEnd)
            }
            do {
                try readEnd.close()
            } catch {
                _ = error
            }
            throw error
        }
    }

    private func closePipeDescriptorIfValid(_ descriptor: Int32) {
        guard descriptor >= 0 else { return }
        _ = backend.closeFileDescriptor(descriptor)
    }

    func closeSourceSendDescriptor(_ descriptor: Int32) throws {
        guard descriptor >= 0 else {
            throw DataTransferError.invalidFileDescriptor(descriptor)
        }

        switch backend.closeFileDescriptor(descriptor) {
        case .closed:
            return
        case .failed(let error):
            throw DataTransferError.closeFileDescriptor(error)
        }
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
                            PrimarySelectionSourceIdentity(sourceID)
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
