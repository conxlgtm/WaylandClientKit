import WaylandRaw

enum OutputManagementSmokeError: Error, Equatable {
    case failed
    case cancelled
    case missingResult
}

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

    func testCurrentOutputConfigurationForSmoke(
        timeoutMilliseconds: Int32
    ) throws {
        try withFatalFailureFinalization {
            try runCurrentOutputConfigurationSmokeTest(
                timeoutMilliseconds: timeoutMilliseconds
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

    private func runCurrentOutputConfigurationSmokeTest(
        timeoutMilliseconds: Int32
    ) throws {
        let session = try requireSession()
        let collection = try collectOutputManagement(
            session: session,
            timeoutMilliseconds: timeoutMilliseconds
        )
        defer { collection.destroy() }

        var result: RawWlrOutputConfigurationEvent?
        let configuration = try collection.manager.createConfiguration(
            serial: collection.snapshot.serial
        ) { event in
            result = event
        }
        defer { configuration.destroy() }

        try collection.configureCurrentState(on: configuration)
        configuration.test()
        try session.connection.completeInitialDiscovery(
            timeoutMilliseconds: timeoutMilliseconds
        )

        try collection.stopAndDrain(
            connection: session.connection,
            timeoutMilliseconds: timeoutMilliseconds
        )
        let resultError = Self.outputManagementSmokeError(for: result)
        if let resultError {
            throw resultError
        }
    }

    static func outputManagementSmokeError(
        for result: RawWlrOutputConfigurationEvent?
    ) -> OutputManagementSmokeError? {
        switch result {
        case .succeeded:
            nil
        case .failed:
            .failed
        case .cancelled:
            .cancelled
        case nil:
            .missingResult
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
