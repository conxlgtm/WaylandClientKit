extension DataTransferStore {
    /// Commits logical and runtime state without calling protocol bindings or publishing events.
    mutating func commit(
        _ transition: PreparedDataTransferTransition
    ) -> [DataTransferPostCommitAction] {
        replaceState(transition.state)
        for preparedDevice in transition.deviceBindings {
            insertPreparedDevice(preparedDevice)
        }
        for source in transition.sourceRecords {
            insertSource(source)
        }
        for offerID in transition.activatedOfferIDs {
            activateOfferForCommit(offerID)
        }

        var postCommitActions: [DataTransferPostCommitAction] = []
        for effect in transition.effects {
            postCommitActions.append(contentsOf: commit(effect))
        }
        return postCommitActions
    }

    mutating func commitShutdown() -> CommittedDataTransferShutdown {
        replaceState(DataTransferState())

        var sources: [RuntimeDataSource] = []
        for sourceID in sourceIDs.sortedByRawValue() {
            if let source = removeSource(sourceID) {
                sources.append(source)
            }
        }
        var offers: [RuntimeDataOffer] = []
        for offerID in offerIDs.sortedByRawValue() {
            if let offer = removeOffer(offerID) {
                offers.append(offer)
            }
        }
        var devices: [any DataTransferDeviceBinding] = []
        for seatID in boundSeatIDs.sortedByRawValue() {
            if let device = removeDeviceBinding(for: seatID) {
                devices.append(device)
            }
        }
        let requests = drainSourceSendRequests()
        discardCallbackFailures()

        return CommittedDataTransferShutdown(
            sources: sources,
            offers: offers,
            devices: devices,
            pendingSourceSendRequests: requests
        )
    }

    private mutating func commit(
        _ effect: DataTransferEffect
    ) -> [DataTransferPostCommitAction] {
        if let event = effect.publishedEvent {
            return [.publish(event)]
        }

        guard let sideEffect = effect.runtimeSideEffect else {
            return []
        }
        switch sideEffect {
        case .bindDataDevice:
            return []
        case .releaseDataDevice(let seatID):
            return commitDeviceRelease(seatID)
        case .destroyOffer(let offerID):
            guard let offer = removeOffer(offerID) else { return [] }
            return [.destroyOffer(offer.binding)]
        case .destroySource(let sourceID):
            guard let source = detachSourcePreservingPendingSends(sourceID) else { return [] }
            return [.destroySource(source.binding)]
        case .cancelSource(let sourceID):
            let source = removeSource(sourceID)
            return [
                .cancelSource(
                    id: sourceID,
                    binding: source?.binding,
                    requests: removeSourceSendRequests(for: sourceID)
                )
            ]
        }
    }

    private mutating func commitDeviceRelease(
        _ seatID: SeatID
    ) -> [DataTransferPostCommitAction] {
        var actions: [DataTransferPostCommitAction] = []
        if let binding = removeDeviceBinding(for: seatID) {
            actions.append(.releaseDevice(binding))
        }
        for offerID in pendingOfferIDs(for: seatID) {
            if let offer = removeOffer(offerID) {
                actions.append(.destroyOffer(offer.binding))
            }
        }
        return actions
    }
}
