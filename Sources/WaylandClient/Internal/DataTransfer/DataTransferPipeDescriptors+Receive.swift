package protocol DataTransferReceiveBinding: AnyObject {
    func receive(mimeType: MIMEType, fd: Int32)
}

package protocol DataTransferReceivePipeBackend: AnyObject {
    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor
    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult
}

package protocol DataTransferOfferReceiveBackend: DataTransferReceivePipeBackend {
    func makeOfferReceivePipe() throws -> DataTransferPipeDescriptors
}

extension DataTransferOfferReceiveBackend {
    package func receiveOffer(
        _ offer: DataOfferSnapshot,
        using binding: any DataTransferReceiveBinding,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        guard offer.mimeTypes.contains(mimeType) else {
            throw DataTransferError.mimeTypeUnavailable(mimeType)
        }

        let descriptors = try makeOfferReceivePipe()
        var readEnd = try descriptors.adoptReadEnd(using: self)
        try descriptors.receive(
            into: binding,
            mimeType: mimeType,
            readEnd: &readEnd,
            using: self
        )
        return readEnd
    }
}

extension DataTransferPipeDescriptors {
    package func adoptReadEnd(
        using backend: any DataTransferReceivePipeBackend
    ) throws -> OwnedFileDescriptor {
        do {
            return try backend.adoptOwnedFileDescriptor(readEnd)
        } catch {
            closeValidPipeDescriptorIfNeeded(readEnd, using: backend)
            closeValidPipeDescriptorIfNeeded(writeEnd, using: backend)
            throw error
        }
    }

    package func receive(
        into binding: any DataTransferReceiveBinding,
        mimeType: MIMEType,
        readEnd: inout OwnedFileDescriptor,
        using backend: any DataTransferReceivePipeBackend
    ) throws {
        var rawWriteEnd: Int32? = writeEnd
        do {
            var adoptedWriteEnd = try backend.adoptOwnedFileDescriptor(writeEnd)
            rawWriteEnd = nil
            binding.receive(mimeType: mimeType, fd: adoptedWriteEnd.rawValue)
            try adoptedWriteEnd.close()
        } catch {
            if let rawWriteEnd {
                closeValidPipeDescriptorIfNeeded(rawWriteEnd, using: backend)
            }
            do {
                try readEnd.close()
            } catch {
                _ = error
            }
            throw error
        }
    }

    package func closeValidPipeDescriptorIfNeeded(
        _ descriptor: Int32,
        using backend: any DataTransferReceivePipeBackend
    ) {
        guard descriptor >= 0 else { return }
        _ = backend.closeFileDescriptor(descriptor)
    }
}
