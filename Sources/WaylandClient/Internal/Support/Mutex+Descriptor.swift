import Synchronization

extension Mutex where Value == Int32? {
    package func takeDescriptor() -> Int32? {
        withLock { storage in
            defer { storage = nil }
            return storage
        }
    }
}
