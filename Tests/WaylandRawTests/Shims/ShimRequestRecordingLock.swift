import Synchronization

enum ShimRequestRecordingLock {
    static let activation = Mutex<Void>(())
    static let pointerCapture = Mutex<Void>(())
    static let primarySelection = Mutex<Void>(())
    static let scale = Mutex<Void>(())
}
