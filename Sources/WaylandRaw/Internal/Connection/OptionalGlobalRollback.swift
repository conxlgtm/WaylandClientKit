package final class OptionalGlobalRollback {
    private var cleanup: [() -> Void] = []

    package init() {}

    package func append(_ operation: @escaping () -> Void) {
        cleanup.append(operation)
    }

    package func disarm() {
        cleanup.removeAll(keepingCapacity: false)
    }

    package func destroyIfArmed() {
        while let operation = cleanup.popLast() {
            operation()
        }
    }

    deinit {
        destroyIfArmed()
    }
}
