import Glibc

package enum RawKeyboardKeymapReader {
    package static let defaultMaximumKeymapSizeBytes: UInt32 = 4 * 1_024 * 1_024
    package static let hardMaximumKeymapSizeBytes: UInt32 = 16 * 1_024 * 1_024

    package static func readKeymap(
        id: RawKeyboardKeymapID,
        format: RawKeyboardKeymapFormat,
        fd: Int32,
        size: UInt32
    ) throws(RawKeyboardKeymapReadError) -> RawKeyboardKeymapPayload {
        try readKeymap(
            id: id,
            format: format,
            fd: fd,
            size: size,
            maximumSize: defaultMaximumKeymapSizeBytes
        ) { descriptor in
            Glibc.close(descriptor)
        }
    }

    package static func readKeymap(
        id: RawKeyboardKeymapID,
        format: RawKeyboardKeymapFormat,
        fd: Int32,
        size: UInt32,
        maximumSize: UInt32 = defaultMaximumKeymapSizeBytes,
        closeFileDescriptor: (Int32) -> Void
    ) throws(RawKeyboardKeymapReadError) -> RawKeyboardKeymapPayload {
        if format == .noKeymap {
            closeIfValid(fd, closeFileDescriptor)
            return .noKeymap(id: id)
        }

        guard format == .xkbV1 else {
            closeIfValid(fd, closeFileDescriptor)
            throw .unsupportedFormat(format: format, advertisedSize: size)
        }

        return try readXKBV1Keymap(
            id: id,
            fd: fd,
            size: size,
            maximumSize: maximumSize,
            closeFileDescriptor: closeFileDescriptor
        )
    }

    private static func closeIfValid(
        _ fd: Int32,
        _ closeFileDescriptor: (Int32) -> Void
    ) {
        if fd >= 0 {
            closeFileDescriptor(fd)
        }
    }

    private static func readXKBV1Keymap(
        id: RawKeyboardKeymapID,
        fd: Int32,
        size: UInt32,
        maximumSize: UInt32,
        closeFileDescriptor: (Int32) -> Void
    ) throws(RawKeyboardKeymapReadError) -> RawKeyboardKeymapPayload {
        guard fd >= 0 else {
            throw .invalidFileDescriptor(fd)
        }

        defer { closeFileDescriptor(fd) }

        guard maximumSize <= hardMaximumKeymapSizeBytes else {
            throw RawKeyboardKeymapReadError.invalidSizeLimit(
                maxSize: maximumSize,
                hardMaximumSize: hardMaximumKeymapSizeBytes
            )
        }

        guard size > 1 else {
            throw RawKeyboardKeymapReadError.emptyXKBV1Payload(size: size)
        }

        guard size <= maximumSize else {
            throw RawKeyboardKeymapReadError.tooLarge(size: size, maxSize: maximumSize)
        }

        var status = stat()
        guard unsafe fstat(fd, &status) == 0 else {
            throw RawKeyboardKeymapReadError.system(errno: errno, operation: .fstat)
        }

        guard status.st_size >= off_t(size) else {
            throw RawKeyboardKeymapReadError.fdTooSmall(
                size: size,
                actualSize: Int64(status.st_size)
            )
        }

        let byteCount = Int(size)
        let failedMapping = unsafe MAP_FAILED
        guard
            let mapping = unsafe mmap(nil, byteCount, PROT_READ, MAP_PRIVATE, fd, 0),
            unsafe mapping != failedMapping
        else {
            throw RawKeyboardKeymapReadError.system(errno: errno, operation: .mmap)
        }

        defer {
            unsafe munmap(mapping, byteCount)
        }

        let bytes = unsafe UnsafeRawBufferPointer(start: mapping, count: byteCount)
        guard unsafe bytes[byteCount - 1] == 0 else {
            throw RawKeyboardKeymapReadError.missingNULTerminator(size: size)
        }

        return .xkbV1(id: id, bytes: try XKBV1KeymapBytes(unsafe Array(bytes)))
    }
}
