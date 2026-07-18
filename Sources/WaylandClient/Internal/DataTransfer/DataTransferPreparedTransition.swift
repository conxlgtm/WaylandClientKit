/// A device binding created before its logical seat transition is committed.
struct PreparedDataTransferDeviceBinding {
    let seatID: SeatID
    let binding: any DataTransferDeviceBinding
}

/// A logical transition with all fallible resource preparation finished.
struct PreparedDataTransferTransition {
    let state: DataTransferState
    let effects: [DataTransferEffect]
    let deviceBindings: [PreparedDataTransferDeviceBinding]
    let sourceRecords: [RuntimeDataSource]
    let activatedOfferIDs: [DataOfferID]
}

/// Work that can run after logical state and runtime ownership have been committed.
enum DataTransferPostCommitAction {
    case releaseDevice(any DataTransferDeviceBinding)
    case destroyOffer(any DataTransferOfferBinding)
    case destroySource(any DataTransferSourceBinding)
    case cancelSource(
        id: DataSourceID,
        binding: (any DataTransferSourceBinding)?,
        requests: [DataTransferSourceSendRequest]
    )
    case publish(DataTransferEvent)
}

/// Resources detached from the store before shutdown calls into their bindings.
struct CommittedDataTransferShutdown {
    let sources: [RuntimeDataSource]
    let offers: [RuntimeDataOffer]
    let devices: [any DataTransferDeviceBinding]
    let pendingSourceSendRequests: [DataTransferSourceSendRequest]
}
