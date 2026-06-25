import Foundation

let toolProcessFixtureLock = NSLock()

func withToolProcessFixtureLock<T>(_ operation: () throws -> T) rethrows -> T {
    toolProcessFixtureLock.lock()
    defer { toolProcessFixtureLock.unlock() }
    return try operation()
}
