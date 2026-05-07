extension DataTransferManager {
    package func receiveOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard let offer = store.offerSnapshot(offerID) else {
            throw DataTransferError.unknownOffer
        }
        guard offer.mimeTypes.contains(mimeType) else {
            throw DataTransferError.mimeTypeUnavailable(mimeType)
        }
        guard let binding = offerBindingsByID[offerID] else {
            throw DataTransferError.offerExpired
        }

        let descriptors = try backend.makeOfferReceivePipe()
        var readEnd = try adoptReadEnd(descriptors)
        try receiveIntoPipe(
            binding,
            mimeType: mimeType,
            descriptors: descriptors,
            readEnd: &readEnd
        )
        return readEnd
    }

    private func adoptReadEnd(
        _ descriptors: DataTransferPipeDescriptors
    ) throws -> OwnedFileDescriptor {
        do {
            return try backend.adoptOwnedFileDescriptor(descriptors.readEnd)
        } catch {
            _ = backend.closeFileDescriptor(descriptors.readEnd)
            _ = backend.closeFileDescriptor(descriptors.writeEnd)
            throw error
        }
    }

    private func receiveIntoPipe(
        _ binding: any DataTransferOfferBinding,
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
                _ = backend.closeFileDescriptor(rawWriteEnd)
            }
            do {
                try readEnd.close()
            } catch {
                _ = error
            }
            throw error
        }
    }
}
