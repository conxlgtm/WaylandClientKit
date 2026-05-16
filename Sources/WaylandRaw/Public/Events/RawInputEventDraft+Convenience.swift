extension RawInputEventDraft {
    package init(deviceID eventDeviceID: RawInputDeviceID, kind eventKind: RawInputEventKind) {
        self.init(
            seatID: eventDeviceID.seatID,
            deviceID: eventDeviceID,
            kind: eventKind
        )
    }

    package init(seatID eventSeatID: RawSeatID, kind eventKind: RawInputEventKind) {
        self.init(
            seatID: eventSeatID,
            deviceID: nil,
            kind: eventKind
        )
    }

    package static func diagnostic(
        seatID eventSeatID: RawSeatID,
        deviceID eventDeviceID: RawInputDeviceID?,
        _ payload: RawInputDiagnosticPayload
    ) -> RawInputEventDraft {
        RawInputEventDraft(
            seatID: eventSeatID,
            deviceID: eventDeviceID,
            kind: .diagnostic(RawInputDiagnostic(payload))
        )
    }
}
