import Synchronization

enum ShimRequestRecordingLock {
    static let data = Mutex<Void>(())
    static let primarySelection = Mutex<Void>(())
    static let scale = Mutex<Void>(())
}
