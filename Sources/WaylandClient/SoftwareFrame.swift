public struct SoftwareFrame {
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
        bytes = frameBytes
    }

    public func withXRGB8888Rows(
        _ body: (_ row: Int, _ pixels: UnsafeMutableBufferPointer<UInt32>) throws -> Void
    ) rethrows {
        let pixels = bytes.bindMemory(to: UInt32.self)
        let visibleWidth = Int(width)
        let visibleHeight = Int(height)
        precondition(wordsPerRow >= visibleWidth)

        for row in 0..<visibleHeight {
            let start = row * wordsPerRow
            let rowPixels = UnsafeMutableBufferPointer(
                start: pixels.baseAddress?.advanced(by: start),
                count: visibleWidth
            )
            try body(row, rowPixels)
        }
    }
}
