import Glibc

extension GBMAllocationError {
    package static func capturedCurrentErrno() -> Int32 {
        errno > 0 ? errno : EIO
    }
}
