package enum GBMAllocationError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidRenderNodeFileDescriptor(Int32)
    case deviceCreationFailed(errno: Int32)
    case deviceDestroyed
    case invalidBufferDimensions(width: UInt32, height: UInt32)
    case bufferAllocationFailed(
        format: UInt32,
        modifier: UInt64,
        flags: UInt32,
        errno: Int32
    )
    case bufferDestroyed
    case exportFailed(errno: Int32)
    case invalidPlaneIndex(Int)
    case planeFileDescriptorAlreadyTaken(Int)

    package var description: String {
        switch self {
        case .invalidRenderNodeFileDescriptor(let descriptor):
            "invalid GBM render node file descriptor \(descriptor)"
        case .deviceCreationFailed(let errorNumber):
            "GBM device creation failed with errno \(errorNumber)"
        case .deviceDestroyed:
            "GBM device was already destroyed"
        case .invalidBufferDimensions(let width, let height):
            "invalid GBM buffer dimensions \(width)x\(height)"
        case .bufferAllocationFailed(let format, let modifier, let flags, let errorNumber):
            "GBM buffer allocation failed for format \(format), modifier \(modifier), "
                + "flags \(flags), errno \(errorNumber)"
        case .bufferDestroyed:
            "GBM buffer was already destroyed"
        case .exportFailed(let errorNumber):
            "GBM dmabuf export failed with errno \(errorNumber)"
        case .invalidPlaneIndex(let index):
            "invalid GBM dmabuf plane index \(index)"
        case .planeFileDescriptorAlreadyTaken(let index):
            "GBM dmabuf plane file descriptor was already taken at index \(index)"
        }
    }
}
