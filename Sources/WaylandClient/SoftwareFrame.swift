@safe
public struct SoftwareFrame: ~Copyable {
    public let width: Int32
    public let height: Int32
    public let stride: Int32
    public let geometry: SoftwareFrameGeometry
    private let bytes: UnsafeMutableRawBufferPointer

    private var wordsPerRow: Int {
        Int(stride) / MemoryLayout<UInt32>.stride
    }

    init(
        width frameWidth: Int32,
        height frameHeight: Int32,
        stride frameStride: Int32,
        geometry frameGeometry: SoftwareFrameGeometry,
        bytes frameBytes: UnsafeMutableRawBufferPointer
    ) throws {
        guard frameWidth > 0, frameHeight > 0 else {
            throw ClientError.invalidWindowState(
                .softwareFrameLayout(
                    .nonPositiveDimensions(width: frameWidth, height: frameHeight)
                )
            )
        }

        let minimumStride = Int(frameWidth).multipliedReportingOverflow(
            by: MemoryLayout<UInt32>.stride
        )
        guard !minimumStride.overflow, minimumStride.partialValue <= Int(Int32.max) else {
            throw ClientError.invalidWindowState(
                .softwareFrameLayout(.minimumStrideOverflow(width: frameWidth))
            )
        }
        guard frameStride >= Int32(minimumStride.partialValue) else {
            throw ClientError.invalidWindowState(
                .softwareFrameLayout(
                    .strideTooSmall(
                        width: frameWidth,
                        stride: frameStride,
                        minimumStride: minimumStride.partialValue
                    )
                )
            )
        }

        let requiredByteCount = Int(frameStride).multipliedReportingOverflow(
            by: Int(frameHeight)
        )
        guard !requiredByteCount.overflow else {
            throw ClientError.invalidWindowState(
                .softwareFrameLayout(
                    .requiredByteCountOverflow(stride: frameStride, height: frameHeight)
                )
            )
        }
        guard frameBytes.count >= requiredByteCount.partialValue else {
            throw ClientError.invalidWindowState(
                .softwareFrameLayout(
                    .storageTooSmall(
                        requiredByteCount: requiredByteCount.partialValue,
                        actualByteCount: frameBytes.count
                    )
                )
            )
        }

        width = frameWidth
        height = frameHeight
        stride = frameStride
        geometry = frameGeometry
        unsafe bytes = frameBytes
    }

    public borrowing func withXRGB8888Rows(
        _ body: (_ row: Int, _ pixels: inout MutableSpan<UInt32>) throws -> Void
    ) rethrows {
        let visibleWidth = Int(width)
        let visibleHeight = Int(height)
        precondition(wordsPerRow >= visibleWidth)

        try unsafe bytes.withMemoryRebound(to: UInt32.self) { pixels in
            for row in 0..<visibleHeight {
                let start = row * wordsPerRow
                let rowPixels = unsafe UnsafeMutableBufferPointer(
                    start: pixels.baseAddress?.advanced(by: start),
                    count: visibleWidth
                )
                var rowSpan = unsafe rowPixels.mutableSpan
                try body(row, &rowSpan)
            }
        }
    }
}
