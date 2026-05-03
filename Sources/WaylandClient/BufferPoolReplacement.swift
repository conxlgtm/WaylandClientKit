import WaylandRaw

package protocol BufferPoolReplacementCandidate: AnyObject {
    var size: TopLevelSize { get }
    var hasBusyBuffers: Bool { get }

    func retire(reason: BufferRetirementReason)
}

extension RawSharedMemoryPool: BufferPoolReplacementCandidate {}

package enum BufferPoolReplacement {
    package static func pool<Pool: BufferPoolReplacementCandidate>(
        for requestedSize: TopLevelSize,
        active activePool: inout Pool?,
        retired retiredPools: inout [Pool],
        create createPool: () throws -> Pool
    ) rethrows -> Pool {
        if let currentPool = activePool,
            currentPool.size == requestedSize
        {
            return currentPool
        }

        let previousPool = activePool
        let replacementPool = try createPool()

        if let previousPool {
            previousPool.retire(reason: .resized)
            if previousPool.hasBusyBuffers {
                retiredPools.append(previousPool)
            }
        }

        activePool = replacementPool
        return replacementPool
    }
}
