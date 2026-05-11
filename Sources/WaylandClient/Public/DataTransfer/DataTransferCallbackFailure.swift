public enum DataTransferCallbackContext: Equatable, Sendable {
    case dataDevice(SeatID)
    case dataOffer(ClipboardOfferIdentity)
    case dragOffer(DragOfferIdentity)
    case dataSource(ClipboardSourceIdentity)
    case dragSource(DragSourceIdentity)
    case primarySelectionDevice(SeatID)
    case primarySelectionOffer(PrimarySelectionOfferIdentity)
    case primarySelectionSource(PrimarySelectionSourceIdentity)
    case sourceWrite(DataTransferDiagnosticSource)
}

public enum DataSourceCallbackEventKind: Equatable, Sendable,
    CustomStringConvertible
{
    case target
    case action
    case dndDropPerformed
    case dndFinished

    public var description: String {
        switch self {
        case .target:
            "target"
        case .action:
            "action"
        case .dndDropPerformed:
            "dnd_drop_performed"
        case .dndFinished:
            "dnd_finished"
        }
    }
}

public struct DataTransferCallbackFailure:
    Error,
    Equatable,
    Sendable,
    CustomStringConvertible
{
    public let context: DataTransferCallbackContext
    public let error: DataTransferError

    public var description: String {
        "\(context): \(error.description)"
    }

    package init(
        context failureContext: DataTransferCallbackContext,
        error failureError: DataTransferError
    ) {
        context = failureContext
        error = failureError
    }
}
