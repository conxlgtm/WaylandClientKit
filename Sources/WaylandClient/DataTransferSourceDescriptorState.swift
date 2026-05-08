package enum DataTransferSourceDescriptorState: Sendable {
    case idle(Int32)
    case writing(Int32, cancellationError: DataTransferError?)
    case cancelledBeforeWriting(DataTransferError)
    case consumed

    package init(rawValue: Int32) {
        self = .idle(rawValue)
    }
}
