import Glibc

package enum RawKeyboardKeymapReader {
    package static let defaultMaximumKeymapSizeBytes: UInt32 = 4 * 1_024 * 1_024
    package static let hardMaximumKeymapSizeBytes: UInt32 = 16 * 1_024 * 1_024

    package static func readKeymap(fd: Int32, size: UInt32) throws -> [UInt8] {
        try readKeymap(
            fd: fd,
            size: size,
            maximumSize: defaultMaximumKeymapSizeBytes
        ) { descriptor in
            Glibc.close(descriptor)
        }
    }

    package static func readKeymap(
        fd: Int32,
        size: UInt32,
        maximumSize: UInt32 = defaultMaximumKeymapSizeBytes,
        closeFileDescriptor: (Int32) -> Void
    ) throws -> [UInt8] {
        guard fd >= 0 else {
            return []
        }

        defer { closeFileDescriptor(fd) }

        guard maximumSize <= hardMaximumKeymapSizeBytes else {
            throw RuntimeError.invalidKeymapSizeLimit(
                maxSize: maximumSize,
                hardMaximumSize: hardMaximumKeymapSizeBytes
            )
        }

        guard size >= 2 else {
            throw RuntimeError.invalidKeymapSize(size)
        }

        guard size <= maximumSize else {
            throw RuntimeError.keymapTooLarge(size: size, maxSize: maximumSize)
        }

        var status = stat()
        guard unsafe fstat(fd, &status) == 0 else {
            throw RuntimeError.systemError(errno: errno)
        }

        guard status.st_size >= off_t(size) else {
            throw RuntimeError.keymapFdTooSmall(size: size, actualSize: Int64(status.st_size))
        }

        let byteCount = Int(size)
        let failedMapping = unsafe MAP_FAILED
        guard
            let mapping = unsafe mmap(nil, byteCount, PROT_READ, MAP_PRIVATE, fd, 0),
            unsafe mapping != failedMapping
        else {
            throw RuntimeError.systemError(errno: errno)
        }

        defer {
            unsafe munmap(mapping, byteCount)
        }

        let bytes = unsafe UnsafeRawBufferPointer(start: mapping, count: byteCount)
        guard unsafe bytes[byteCount - 1] == 0 else {
            throw RuntimeError.keymapNotNullTerminated(size: size)
        }

        return unsafe Array(bytes)
    }
}
