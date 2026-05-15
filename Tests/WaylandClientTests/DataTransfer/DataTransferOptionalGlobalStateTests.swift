import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferOptionalGlobalStateTests {
    @Test
    func missingDataDeviceManagerMapsToBoundWithoutManager() {
        let manager = OptionalDataDeviceManager.missing

        #expect(manager.dataTransferBindingState == .boundWithoutDataDeviceManager)
    }

    @Test
    func missingPrimarySelectionManagerMapsToBoundWithoutManager() {
        let manager = OptionalPrimarySelectionDeviceManager.missing

        #expect(manager.primarySelectionBindingState == .boundWithoutPrimaryManager)
    }
}
