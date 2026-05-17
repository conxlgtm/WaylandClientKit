import WaylandRaw

package struct DragIconRoleResources: Equatable, Sendable {}

package final class DragIconRoleSurface: DataTransferDragIconBinding {
    let surface: RawSurface
    private var runtime: SurfaceRuntime<DragIconRoleResources>
    private var isDestroyed = false
    private let committedByteCount: Int

    package init(
        surface iconSurface: RawSurface,
        sharedMemory: RawSharedMemory,
        image: DragIconImage
    ) throws {
        surface = iconSurface
        runtime = SurfaceRuntime(role: .dragIcon, surfaceID: iconSurface.objectID)
        committedByteCount = image.pixels.count * MemoryLayout<UInt32>.stride
        try runtime.installRoleResources(DragIconRoleResources())
        try commit(image: image, sharedMemory: sharedMemory)
    }

    package func committedBytesForTesting() -> [UInt8] {
        runtime.buffers?.mappedBytes(prefixByteCount: committedByteCount) ?? []
    }

    private func commit(image: DragIconImage, sharedMemory: RawSharedMemory) throws {
        let pool = try sharedMemory.createPool(
            width: image.size.width.rawValue,
            height: image.size.height.rawValue,
            bufferCount: 1
        )
        runtime.buffers = pool

        guard var drawingBuffer = pool.acquireDrawingBuffer() else {
            throw DataTransferError.cancelled
        }

        do {
            try unsafe drawingBuffer.withUnsafeMutableBytes { bytes in
                try unsafe image.pixels.withUnsafeBytes { sourceBytes in
                    guard sourceBytes.count <= bytes.count else {
                        throw DataTransferError.invalidDragIconPixelCount(
                            expected: sourceBytes.count,
                            actual: bytes.count
                        )
                    }

                    unsafe bytes.copyMemory(from: sourceBytes)
                }
            }

            let buffer = drawingBuffer.markBusy(commitGeneration: 1)
            surface.attach(buffer: buffer)
            surface.damageFullBuffer(
                width: image.size.width.rawValue,
                height: image.size.height.rawValue
            )
            surface.commit()
        } catch {
            drawingBuffer.discard()
            throw error
        }
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        _ = runtime.removeRoleResources()
        runtime.retireSharedMemoryPools(reason: .destroyed)
        do {
            try runtime.markSurfaceDestroyed()
        } catch {
            assertionFailure("drag icon surface destroy failed: \(error)")
        }
        surface.destroy()
    }

    deinit {
        destroy()
    }
}
