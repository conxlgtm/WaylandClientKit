import WaylandRaw

extension DisplayCore {
    func outputManagementSnapshot(
        timeoutMilliseconds: Int32
    ) throws -> OutputManagementSnapshot {
        try withFatalFailureFinalization {
            let session = try requireSession()
            let collection = try collectOutputManagement(
                session: session,
                timeoutMilliseconds: timeoutMilliseconds
            )
            defer { collection.destroy() }

            let snapshot = collection.snapshot
            try collection.stopAndDrain(
                connection: session.connection,
                timeoutMilliseconds: timeoutMilliseconds
            )
            return snapshot
        }
    }

    func testOutputConfiguration(
        _ proposal: OutputConfigurationProposal,
        timeoutMilliseconds: Int32
    ) throws {
        try withFatalFailureFinalization {
            try runCurrentOutputConfiguration(
                proposal,
                timeoutMilliseconds: timeoutMilliseconds,
                apply: false
            )
        }
    }

    func applyOutputConfiguration(
        _ proposal: OutputConfigurationProposal,
        timeoutMilliseconds: Int32
    ) throws {
        try withFatalFailureFinalization {
            try runCurrentOutputConfiguration(
                proposal,
                timeoutMilliseconds: timeoutMilliseconds,
                apply: true
            )
        }
    }

    func outputManagementHeadID(for name: String?) -> OutputManagementHeadID {
        guard let name else {
            return outputManagementHeadIDs.next()
        }

        if let existing = outputManagementHeadIDsByName[name] {
            return existing
        }

        let id = outputManagementHeadIDs.next()
        outputManagementHeadIDsByName[name] = id
        return id
    }

    func outputManagementModeID(
        for key: OutputManagementModeStableKey?
    ) -> OutputManagementModeID {
        guard let key else {
            return outputManagementModeIDs.next()
        }

        if let existing = outputManagementModeIDsByStableKey[key] {
            return existing
        }

        let id = outputManagementModeIDs.next()
        outputManagementModeIDsByStableKey[key] = id
        return id
    }

    private func runCurrentOutputConfiguration(
        _ proposal: OutputConfigurationProposal,
        timeoutMilliseconds: Int32,
        apply shouldApply: Bool
    ) throws {
        let session = try requireSession()
        let collection = try collectOutputManagement(
            session: session,
            timeoutMilliseconds: timeoutMilliseconds
        )
        defer { collection.destroy() }

        try Self.validateOutputConfigurationProposal(
            proposal,
            against: collection.snapshot
        )

        var result: RawWlrOutputConfigurationEvent?
        let configuration = try collection.manager.createConfiguration(
            serial: collection.snapshot.serial
        ) { event in
            result = event
        }
        defer { configuration.destroy() }

        try collection.configureCurrentState(on: configuration)
        if shouldApply {
            configuration.apply()
        } else {
            configuration.test()
        }
        try session.connection.completeInitialDiscovery(
            timeoutMilliseconds: timeoutMilliseconds
        )

        try collection.stopAndDrain(
            connection: session.connection,
            timeoutMilliseconds: timeoutMilliseconds
        )
        let resultError = Self.outputManagementConfigurationError(for: result)
        if let resultError {
            throw resultError
        }
    }

    static func outputManagementConfigurationError(
        for result: RawWlrOutputConfigurationEvent?
    ) -> ClientError? {
        switch result {
        case .succeeded:
            nil
        case .failed:
            ClientError.display(.outputConfigurationFailed)
        case .cancelled:
            ClientError.display(.outputConfigurationCancelled)
        case nil:
            ClientError.display(.outputConfigurationFailed)
        }
    }

    static func validateOutputConfigurationProposal(
        _ proposal: OutputConfigurationProposal,
        against snapshot: OutputManagementSnapshot
    ) throws {
        guard snapshot.serial == proposal.snapshot.serial else {
            throw ClientError.display(.staleOutputConfiguration)
        }
    }

    private func collectOutputManagement(
        session: DisplaySession,
        timeoutMilliseconds: Int32
    ) throws -> OutputManagementCollection {
        let collector = OutputManagementCollector(core: self)
        guard
            let manager = try session.connection.bindWlrOutputManagerOneShot(
                onEvent: collector.handle
            )
        else {
            throw ClientError.display(.outputManagementUnavailable)
        }

        do {
            try session.connection.completeInitialDiscovery(
                timeoutMilliseconds: timeoutMilliseconds
            )
            return try collector.collection(manager: manager)
        } catch {
            manager.stop()
            do {
                try session.connection.completeInitialDiscovery(
                    timeoutMilliseconds: timeoutMilliseconds
                )
            } catch {
                _ = error
            }
            manager.destroy()
            throw error
        }
    }
}
