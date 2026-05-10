#if DEBUG
    import WaylandRaw

    extension WaylandDisplay {
        package func rawTopLevelPointerAddressForTesting(
            _ windowID: WindowID
        ) throws -> UInt? {
            try requireCore().surfaces.window(windowID)?.topLevelPointerAddressForTesting
        }

        package func firstRawOutputForTesting() throws -> (
            id: OutputID,
            pointerAddress: UInt
        )? {
            let globals = try requireCore().requireSession().connection.bindRequiredGlobals()
            guard let output = globals.outputRegistry.snapshots.first else {
                return nil
            }
            guard
                let rawOutput = globals.outputRegistry.output(for: output.id)
            else {
                return nil
            }

            return (
                OutputID(rawValue: output.id.rawValue),
                rawOutput.pointerAddressForTesting
            )
        }

        package func firstRawSeatForTesting() throws -> (
            id: SeatID,
            pointerAddress: UInt
        )? {
            let globals = try requireCore().requireSession().connection.bindRequiredGlobals()
            guard let seat = globals.seatRegistry.seats.first else {
                return nil
            }

            return (
                SeatID(rawValue: seat.id.rawValue),
                seat.pointerAddressForTesting
            )
        }

        package func insertWindowInteractionSeatForTesting(
            windowID: WindowID,
            seatID: SeatID,
            pointerAddress: Int
        ) throws -> (id: SeatID, pointerAddress: UInt) {
            guard let window = try requireCore().surfaces.window(windowID) else {
                throw ClientError.display(.unknownWindow(windowID))
            }
            let pointerAddress = try window.installInteractionSeatForTesting(
                id: seatID,
                pointerAddress: pointerAddress
            )

            return (
                seatID,
                pointerAddress
            )
        }

        package func removeWindowInteractionSeatForTesting(
            windowID: WindowID,
            seatID: SeatID
        ) throws {
            try requireCore().surfaces.window(windowID)?
                .removeInteractionSeatForTesting(seatID)
        }
    }
#endif
