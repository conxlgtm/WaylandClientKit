public enum DataTransferCallbackContext: Equatable, Sendable {
    case dataDevice(SeatID)
    case dataOffer(ClipboardOfferIdentity)
    case dataSource(ClipboardSourceIdentity)
    case primarySelectionDevice(SeatID)
    case primarySelectionOffer(PrimarySelectionOfferIdentity)
    case primarySelectionSource(PrimarySelectionSourceIdentity)
    case sourceWrite(DataTransferDiagnosticSource)
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
