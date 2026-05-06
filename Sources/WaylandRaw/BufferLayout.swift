import Glibc

package struct BufferLayout: Equatable, Sendable {
    package let width: Int32
    package let height: Int32
    package let stride: Int32
    package let byteCount: Int

    package init(width bufferWidth: Int32, height bufferHeight: Int32) throws(RuntimeError) {
        guard bufferWidth > 0, bufferHeight > 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL, operation: .validateArgument("buffer dimensions"))
        }

        let strideResult = Int(bufferWidth).multipliedReportingOverflow(
            by: MemoryLayout<UInt32>.stride
        )
        guard !strideResult.overflow, strideResult.partialValue <= Int(Int32.max) else {
            throw RuntimeError.systemError(
                errno: EOVERFLOW, operation: .validateArgument("buffer stride"))
        }

        let byteCountResult = strideResult.partialValue
            .multipliedReportingOverflow(by: Int(bufferHeight))
        guard !byteCountResult.overflow else {
            throw RuntimeError.systemError(
                errno: EOVERFLOW, operation: .validateArgument("buffer byte count"))
        }

        width = bufferWidth
        height = bufferHeight
        stride = Int32(strideResult.partialValue)
        byteCount = byteCountResult.partialValue
    }
}
