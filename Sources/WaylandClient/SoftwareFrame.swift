@safe
public struct SoftwareFrame: ~Copyable {
    public let width: Int32
    public let height: Int32
    public let stride: Int32
    private let bytes: UnsafeMutableRawBufferPointer

    private var wordsPerRow: Int {
        Int(stride) / MemoryLayout<UInt32>.stride
    }

    init(
        width frameWidth: Int32,
        height frameHeight: Int32,
        stride frameStride: Int32,
        bytes frameBytes: UnsafeMutableRawBufferPointer
    ) {
        width = frameWidth
        height = frameHeight
        stride = frameStride
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
