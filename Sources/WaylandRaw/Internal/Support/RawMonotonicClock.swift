import Glibc

func rawMonotonicMilliseconds() throws -> Int64 {
    var timestamp = timespec()
    guard unsafe clock_gettime(CLOCK_MONOTONIC, &timestamp) == 0 else {
        throw RuntimeError.systemError(errno: errno, operation: .readMonotonicClock)
    }

    return Int64(timestamp.tv_sec) * 1_000 + Int64(timestamp.tv_nsec) / 1_000_000
}
