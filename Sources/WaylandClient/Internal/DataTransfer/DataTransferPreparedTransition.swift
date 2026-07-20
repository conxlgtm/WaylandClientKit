/// A logical transition with all fallible resource preparation finished.
struct PreparedDataTransferTransition {
    let state: DataTransferState
    let effects: [DataTransferEffect]
    let sourceRecords: [RuntimeDataSource]
    let activatedOfferIDs: [DataOfferID]
}

/// Work that can run after logical state and runtime ownership have been committed.
enum DataTransferPostCommitAction {
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
}
