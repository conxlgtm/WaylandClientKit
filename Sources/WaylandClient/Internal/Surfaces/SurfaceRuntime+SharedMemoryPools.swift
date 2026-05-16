import WaylandRaw

extension SurfaceRuntime {
    mutating func sharedMemoryPool(
        for size: PositivePixelSize,
        create createPool: () throws -> RawSharedMemoryPool
    ) rethrows -> RawSharedMemoryPool {
        var activePool = buffers
        var retiredPools = retiredBufferPools
        let pool = try BufferPoolReplacement.pool(
            for: size.rawSize,
            active: &activePool,
            retired: &retiredPools,
            create: createPool
        )
        buffers = activePool
        retiredBufferPools = retiredPools
        return pool
    }

    mutating func dropReleasedRetiredBufferPools() {
        retiredBufferPools.removeAll { pool in
            !pool.hasBusyBuffers
        }
    }

    mutating func retireSharedMemoryPools(reason: BufferRetirementReason) {
        if let activeBuffers = buffers {
            activeBuffers.retire(reason: reason)
            if activeBuffers.hasBusyBuffers {
                retiredBufferPools.append(activeBuffers)
            }
            buffers = nil
        }

        for pool in retiredBufferPools {
            pool.retire(reason: reason)
        }
        dropReleasedRetiredBufferPools()
    }

    func redrawBufferAvailability(
        matching bufferSize: TopLevelSize
    ) -> RedrawBufferAvailability {
        guard let buffers else { return .available }

        if buffers.size != bufferSize {
            return .available
        }

        return RedrawBufferAvailability(isAvailable: buffers.hasFreeBuffers)
    }
}
