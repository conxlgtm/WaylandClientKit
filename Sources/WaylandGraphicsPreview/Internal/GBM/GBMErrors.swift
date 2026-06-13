package enum GBMAllocationError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidRenderNodeFileDescriptor(Int32)
    case invalidDeviceIDByteCount(expected: Int, actual: Int)
    case renderNodeLookupFailed(errno: Int32)
    case openRenderNodeFailed(path: String, errno: Int32)
    case deviceCreationFailed(errno: Int32)
    case deviceDestroyed
    case invalidBufferDimensions(width: UInt32, height: UInt32)
    case bufferAllocationFailed(
        format: UInt32,
        modifier: UInt64,
        flags: UInt32,
        errno: Int32
    )
    case surfaceCreationFailed(
        format: UInt32,
        modifier: UInt64,
        flags: UInt32,
        errno: Int32
    )
    case bufferDestroyed
    case surfaceDestroyed
    case surfaceFrontBufferLockFailed(errno: Int32)
    case exportFailed(errno: Int32)
    case syncobjCreationFailed(errno: Int32)
    case syncobjFileDescriptorExportFailed(errno: Int32)
    case syncobjTimelineSignalFailed(point: UInt64, errno: Int32)
    case syncobjTimelineWaitFailed(point: UInt64, errno: Int32)
    case invalidPlaneIndex(Int)
    case planeFileDescriptorAlreadyTaken(Int)

    package var description: String {
        switch self {
        case .invalidRenderNodeFileDescriptor(let descriptor):
            "invalid GBM render node file descriptor \(descriptor)"
        case .invalidDeviceIDByteCount(let expected, let actual):
            "invalid DRM device ID byte count \(actual), expected \(expected)"
        case .renderNodeLookupFailed(let errorNumber):
            "DRM render node lookup failed with errno \(errorNumber)"
        case .openRenderNodeFailed(let path, let errorNumber):
            "open DRM render node \(path) failed with errno \(errorNumber)"
        case .deviceCreationFailed(let errorNumber):
            "GBM device creation failed with errno \(errorNumber)"
        case .deviceDestroyed:
            "GBM device was already destroyed"
        case .invalidBufferDimensions(let width, let height):
            "invalid GBM buffer dimensions \(width)x\(height)"
        case .bufferAllocationFailed(let format, let modifier, let flags, let errorNumber):
            "GBM buffer allocation failed for format \(format), modifier \(modifier), "
                + "flags \(flags), errno \(errorNumber)"
        case .surfaceCreationFailed(let format, let modifier, let flags, let errorNumber):
            "GBM surface creation failed for format \(format), modifier \(modifier), "
                + "flags \(flags), errno \(errorNumber)"
        case .bufferDestroyed:
            "GBM buffer was already destroyed"
        case .surfaceDestroyed:
            "GBM surface was already destroyed"
        case .surfaceFrontBufferLockFailed(let errorNumber):
            "GBM surface front-buffer lock failed with errno \(errorNumber)"
        case .exportFailed(let errorNumber):
            "GBM dmabuf export failed with errno \(errorNumber)"
        case .syncobjCreationFailed(let errorNumber):
            "DRM syncobj timeline creation failed with errno \(errorNumber)"
        case .syncobjFileDescriptorExportFailed(let errorNumber):
            "DRM syncobj timeline fd export failed with errno \(errorNumber)"
        case .syncobjTimelineSignalFailed(let point, let errorNumber):
            "DRM syncobj timeline signal for point \(point) failed with errno \(errorNumber)"
        case .syncobjTimelineWaitFailed(let point, let errorNumber):
            "DRM syncobj timeline wait for point \(point) failed with errno \(errorNumber)"
        case .invalidPlaneIndex(let index):
            "invalid GBM dmabuf plane index \(index)"
        case .planeFileDescriptorAlreadyTaken(let index):
            "GBM dmabuf plane file descriptor was already taken at index \(index)"
        }
    }
}
