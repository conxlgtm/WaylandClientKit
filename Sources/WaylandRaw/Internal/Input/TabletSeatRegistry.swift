@safe
package final class TabletSeatRegistry {
    private let manager: RawTabletManager
    private let eventSink: RawInputEventSink
    private var tabletSeatsBySeatID: [RawSeatID: RawTabletSeat] = [:]
    private var isDestroyed = false

    package init(manager tabletManager: RawTabletManager, eventSink tabletEventSink: RawInputEventSink) {
        manager = tabletManager
        eventSink = tabletEventSink
    }

    package func bindTabletSeats(from seats: [RawSeat]) {
        for seat in seats {
            bindTabletSeat(for: seat)
        }
    }

    package func bindTabletSeat(for seat: RawSeat) {
        guard !isDestroyed, tabletSeatsBySeatID[seat.id] == nil else { return }

        do {
            let tabletSeat = try manager.tabletSeat(for: seat, eventSink: eventSink)
            tabletSeatsBySeatID[seat.id] = tabletSeat
        } catch {
            appendSeatBindingDiagnostic(seatID: seat.id, error: error)
        }
    }

    package func removeSeat(globalName: UInt32) {
        let seatID = RawSeatID(rawValue: globalName)
        tabletSeatsBySeatID.removeValue(forKey: seatID)?.destroy()
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        let tabletSeats = tabletSeatsBySeatID
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map(\.value)
        tabletSeatsBySeatID.removeAll()

        for tabletSeat in tabletSeats {
            tabletSeat.destroy()
        }
    }

    private func appendSeatBindingDiagnostic(seatID: RawSeatID, error: any Error) {
        let deviceID = RawInputDeviceID(seatID: seatID, kind: .tablet, generation: 1)
        let payload: RawInputDiagnosticPayload
        if let runtimeError = error as? RuntimeError {
            payload = .seatBinding(
                RawSeatBindingDiagnostic(
                    interface: "zwp_tablet_seat_v2",
                    error: runtimeError
                )
            )
        } else {
            payload = .listener(
                RawListenerDiagnostic(
                    listener: "zwp_tablet_seat_v2",
                    message: String(describing: error)
                )
            )
        }

        eventSink.append(
            RawInputEventDraft.diagnostic(
                seatID: seatID,
                deviceID: deviceID,
                payload
            )
        )
    }

    deinit {
        destroy()
    }
}
