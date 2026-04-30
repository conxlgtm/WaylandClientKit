import Glibc

package enum WaylandThreadExecutorWakeSignalResult: Equatable, Sendable {
    case signaled
    case alreadyPending
}

extension WaylandThreadExecutor {
    package static func drainWakeFileDescriptor(
        _ fileDescriptor: CInt
    ) throws(WaylandThreadExecutorError) {
        var value = UInt64(0)
        while true {
            let bytesRead = unsafe withUnsafeMutablePointer(to: &value) { pointer in
                unsafe read(fileDescriptor, pointer, MemoryLayout<UInt64>.size)
            }

            if bytesRead == MemoryLayout<UInt64>.size {
                continue
            }

            if bytesRead < 0 {
                let savedErrno = errno
                if savedErrno == EINTR {
                    continue
                }
                if savedErrno == EAGAIN {
                    return
                }

                throw .wakeFileDescriptorReadFailed(savedErrno)
            }

            throw .wakeFileDescriptorShortRead(bytesRead)
        }
    }

    package static func signalWakeFileDescriptor(
        _ fileDescriptor: CInt
    ) throws(WaylandThreadExecutorError) -> WaylandThreadExecutorWakeSignalResult {
        var value = UInt64(1)
        while true {
            let bytesWritten = unsafe withUnsafePointer(to: &value) { pointer in
                unsafe write(fileDescriptor, pointer, MemoryLayout<UInt64>.size)
            }

            if bytesWritten == MemoryLayout<UInt64>.size {
                return .signaled
            }

            if bytesWritten < 0 {
                let savedErrno = errno
                if savedErrno == EINTR {
                    continue
                }
                if savedErrno == EAGAIN {
                    return .alreadyPending
                }

                throw .wakeFileDescriptorWriteFailed(savedErrno)
            }

            throw .wakeFileDescriptorShortWrite(bytesWritten)
        }
    }
}
