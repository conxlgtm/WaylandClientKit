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
        let fd = name.withCString { namePointer in
            swl_memfd_create(namePointer, swl_mfd_cloexec())
        }

        guard fd >= 0 else {
            throw RuntimeError.systemError(errno: errno)
        }

        return RawFileDescriptor(fd)
    }

    package func resize(byteCount: Int) throws(RuntimeError) {
        guard ftruncate(rawValue, off_t(byteCount)) == 0 else {
            throw RuntimeError.systemError(errno: errno)
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
