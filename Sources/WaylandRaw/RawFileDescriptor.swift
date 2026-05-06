import CWaylandProtocols
import Glibc

package struct RawFileDescriptor: ~Copyable {
    private var storage: Int32?

    package init(_ fileDescriptor: Int32) {
        precondition(fileDescriptor >= 0, "Invalid file descriptor")
        storage = fileDescriptor
    }

    package var rawValue: Int32 {
        guard let storage else {
            preconditionFailure("File descriptor was already closed")
        }

        return storage
    }

    package static func memfd(name: String) throws(RuntimeError) -> RawFileDescriptor {
        let fd = unsafe name.withCString { namePointer in
            unsafe swl_memfd_create(namePointer, swl_mfd_cloexec())
        }

        guard fd >= 0 else {
            throw RuntimeError.systemError(errno: errno, operation: .createSharedMemoryFile)
        }

        return RawFileDescriptor(fd)
    }

    package static func pipeDescriptors() throws(RuntimeError) -> (
        readEnd: Int32,
        writeEnd: Int32
    ) {
        var descriptors = [Int32](repeating: -1, count: 2)
        let result = unsafe descriptors.withUnsafeMutableBufferPointer { descriptorBuffer in
            unsafe Glibc.pipe(descriptorBuffer.baseAddress)
        }

        guard result == 0 else {
            throw RuntimeError.systemError(errno: errno, operation: .createPipe)
        }

        return (readEnd: descriptors[0], writeEnd: descriptors[1])
    }

    package static func read(
        descriptor fileDescriptor: Int32,
        maximumByteCount: Int
    ) throws(RuntimeError) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: maximumByteCount)
        let readCount = unsafe buffer.withUnsafeMutableBufferPointer { byteBuffer in
            unsafe Glibc.read(fileDescriptor, byteBuffer.baseAddress, maximumByteCount)
        }

        guard readCount >= 0 else {
            throw RuntimeError.systemError(errno: errno, operation: .readFileDescriptor)
        }

        return Array(buffer.prefix(Int(readCount)))
    }

    package static func write(
        descriptor fileDescriptor: Int32,
        bytes: [UInt8]
    ) throws(RuntimeError) -> Int {
        var writableBytes = bytes
        let writeCount = unsafe writableBytes.withUnsafeMutableBufferPointer { byteBuffer in
            unsafe swl_write_no_sigpipe(fileDescriptor, byteBuffer.baseAddress, byteBuffer.count)
        }

        guard writeCount >= 0 else {
            throw RuntimeError.systemError(errno: errno, operation: .writeFileDescriptor)
        }

        return Int(writeCount)
    }

    package func resize(byteCount: Int) throws(RuntimeError) {
        guard ftruncate(rawValue, off_t(byteCount)) == 0 else {
            throw RuntimeError.systemError(errno: errno, operation: .resizeSharedMemoryFile)
        }
    }

    package mutating func close() {
        guard let fd = storage else { return }

        storage = nil
        Glibc.close(fd)
    }

    deinit {
        if let storage {
            Glibc.close(storage)
        }
    }
}
