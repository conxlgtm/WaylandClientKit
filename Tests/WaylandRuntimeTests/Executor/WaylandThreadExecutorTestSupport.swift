#if ENABLE_TESTING
    import Glibc

    struct ExecutorTestPipeSignalError: Error, CustomStringConvertible {
        var description: String
    }

    func makeExecutorTestPipeDescriptors() throws -> (readEnd: CInt, writeEnd: CInt) {
        var descriptors = [CInt](repeating: -1, count: 2)
        let result = unsafe descriptors.withUnsafeMutableBufferPointer { buffer in
            unsafe Glibc.pipe(buffer.baseAddress)
        }
        guard result == 0 else {
            throw ExecutorTestPipeSignalError(description: "pipe failed with errno \(errno)")
        }

        return (readEnd: descriptors[0], writeEnd: descriptors[1])
    }

    func waitForExecutorTestPipeSignal(_ descriptor: CInt) throws {
        var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        let result = unsafe Glibc.poll(&pollDescriptor, 1, 1_000)
        guard result > 0 else {
            throw ExecutorTestPipeSignalError(
                description: "timed out waiting for read failure signal"
            )
        }

        var byte = UInt8(0)
        let readCount = unsafe withUnsafeMutableBytes(of: &byte) { buffer in
            unsafe Glibc.read(descriptor, buffer.baseAddress, 1)
        }
        guard readCount == 1 else {
            throw ExecutorTestPipeSignalError(
                description: "read signal failed with errno \(errno)"
            )
        }
    }

    func closeExecutorTestDescriptor(_ descriptor: CInt) {
        guard descriptor >= 0 else {
            return
        }

        _ = Glibc.close(descriptor)
    }
#endif
