import Testing

@testable import WaylandRaw

@Suite
struct RawInputIdentityTests {
    @Test
    func seatIDDescriptionUsesRegistryNameShape() {
        let seatID = RawSeatID(rawValue: 42)

        #expect(seatID.rawValue == 42)
        #expect(seatID.description == "seat-42")
    }

    @Test
    func deviceIDPreservesSeatKindAndGeneration() {
        let seatID = RawSeatID(rawValue: 3)
        let deviceID = RawInputDeviceID(
            seatID: seatID,
            kind: .pointer,
            generation: 7
        )

        #expect(deviceID.seatID == seatID)
        #expect(deviceID.kind == .pointer)
        #expect(deviceID.generation == 7)
        #expect(deviceID.description == "seat-3.pointer-7")
    }

    @Test
    func seatCapabilitiesPreserveUnknownBits() {
        let capabilities = SeatCapabilities(rawValue: 0x80)

        #expect(capabilities.rawValue == 0x80)
        #expect(!capabilities.hasPointer)
        #expect(!capabilities.hasKeyboard)
        #expect(!capabilities.hasTouch)
    }

    @Test
    func seatCapabilitiesDescribeKnownValues() {
        let capabilities: SeatCapabilities = [.pointer, .keyboard]

        #expect(capabilities.hasPointer)
        #expect(capabilities.hasKeyboard)
        #expect(!capabilities.hasTouch)
        #expect(capabilities.description == "pointer+keyboard")
        #expect(SeatCapabilities().description == "none")
    }

    @Test
    func waylandFixedConvertsToDouble() {
        let fixed = WaylandFixed(rawValue: 384)

        #expect(fixed.doubleValue == 1.5)
        #expect(fixed.description == "1.5")
    }
}
