package enum DataSourceCallbackIdentity {
    case selection(ClipboardSourceIdentity)
    case dragAndDrop(DragSourceIdentity)

    package var context: DataTransferCallbackContext {
        switch self {
        case .selection(let source):
            .dataSource(source)
        case .dragAndDrop(let source):
            .dragSource(source)
        }
    }

    package var unknownSourceError: DataTransferError {
        switch self {
        case .selection(let source):
            .unknownSourceIdentity(source)
        case .dragAndDrop(let source):
            .unknownDragSourceIdentity(source)
        }
    }

    package var isSelection: Bool {
        if case .selection = self {
            return true
        }
        return false
    }
}
