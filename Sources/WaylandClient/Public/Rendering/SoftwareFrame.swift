@safe
package struct SoftwareFrameReservationToken: UInt64WaylandEntityID {
    package let rawValue: UInt64

    package init(rawValue reservationRawValue: UInt64) {
        rawValue = reservationRawValue
    }

    package var description: String {
        "software-frame-reservation-\(rawValue)"
    }
}

@safe
public struct SoftwareFrameBufferID: Hashable, Sendable {
    private let rawValue: ObjectIdentifier

    init(rawValue bufferObjectIdentifier: ObjectIdentifier) {
        rawValue = bufferObjectIdentifier
    }
}

@safe
public struct SoftwareFrameBuffer: ~Copyable {
    public let id: SoftwareFrameBufferID
    public let width: Int32
    public let height: Int32
    public let stride: Int32
    public let geometry: SoftwareFrameGeometry
    private let bytes: UnsafeMutableRawBufferPointer

    init(
        id frameBufferID: SoftwareFrameBufferID,
        width frameWidth: Int32,
        height frameHeight: Int32,
        stride frameStride: Int32,
        geometry frameGeometry: SoftwareFrameGeometry,
        bytes frameBytes: UnsafeMutableRawBufferPointer
    ) {
        id = frameBufferID
        width = frameWidth
        height = frameHeight
        stride = frameStride
        geometry = frameGeometry
        unsafe bytes = frameBytes
    }

    public borrowing func withUnsafeMutableBytes<Result>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        try unsafe body(bytes)
    }
}

@safe
public struct SoftwareFrameReservation: Equatable, Sendable {
    public let id: SoftwareFrameBufferID
    public let width: Int32
    public let height: Int32
    public let stride: Int32
    public let geometry: SoftwareFrameGeometry
    package let reservationID: SoftwareFrameReservationToken

    package init(
        reservationID frameReservationID: SoftwareFrameReservationToken,
        id frameBufferID: SoftwareFrameBufferID,
        width frameWidth: Int32,
        height frameHeight: Int32,
        stride frameStride: Int32,
        geometry frameGeometry: SoftwareFrameGeometry
    ) {
        reservationID = frameReservationID
        id = frameBufferID
        width = frameWidth
        height = frameHeight
        stride = frameStride
        geometry = frameGeometry
    }
}

@safe
public struct SoftwareFrame: ~Copyable {
    public let id: SoftwareFrameBufferID
    public let width: Int32
    public let height: Int32
    public let stride: Int32
    public let geometry: SoftwareFrameGeometry
    private let bytes: UnsafeMutableRawBufferPointer

    private var wordsPerRow: Int {
        Int(stride) / MemoryLayout<UInt32>.stride
    }

    init(
        id frameBufferID: SoftwareFrameBufferID,
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

        id = frameBufferID
        width = frameWidth
        height = frameHeight
        stride = frameStride
        geometry = frameGeometry
        unsafe bytes = frameBytes
    }

    public borrowing func withBuffer<Result>(
        _ body: (borrowing SoftwareFrameBuffer) throws -> Result
    ) rethrows -> Result {
        let frameBuffer = SoftwareFrameBuffer(
            id: id,
            width: width,
            height: height,
            stride: stride,
            geometry: geometry,
            bytes: bytes
        )
        return try body(frameBuffer)
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
