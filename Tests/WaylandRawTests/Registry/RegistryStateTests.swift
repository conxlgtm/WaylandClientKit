import Testing

@testable import WaylandRaw

@Suite
struct RegistryStateTests {
    @Test
    func recordsGlobal() {
        let state = RegistryState()
        #expect(state.recordGlobal(name: 4, interfaceName: "wl_compositor", version: 6))
        let global = state.firstGlobal(named: "wl_compositor")
        #expect(global != nil)
        #expect(global?.name == 4)
        #expect(global?.advertisedVersion == RawVersion(6))
        #expect(state.rejectedGlobals.isEmpty)
    }
    @Test
    func removesGlobal() {
        let state = RegistryState()
        state.recordGlobal(name: 4, interfaceName: "wl_compositor", version: 6)
        state.removeGlobal(name: 4)
        #expect(state.firstGlobal(named: "wl_compositor") == nil)
    }
    @Test
    func snapshotReturnsSortedByName() {
        let state = RegistryState()
        state.recordGlobal(name: 10, interfaceName: "wl_shm", version: 1)
        state.recordGlobal(name: 3, interfaceName: "wl_compositor", version: 6)
        state.recordGlobal(name: 7, interfaceName: "xdg_wm_base", version: 4)
        let names = state.snapshot.map(\.name)
        #expect(names == [3, 7, 10])
    }
    @Test
    func firstGlobalReturnsNilForUnknownInterface() {
        let state = RegistryState()
        state.recordGlobal(name: 1, interfaceName: "wl_compositor", version: 6)
        #expect(state.firstGlobal(named: "wl_shm") == nil)
    }

    @Test
    func firstGlobalChoosesHighestAdvertisedVersionForDuplicateInterfaces() {
        let state = RegistryState()
        state.recordGlobal(name: 1, interfaceName: "zxdg_output_manager_v1", version: 1)
        state.recordGlobal(name: 2, interfaceName: "zxdg_output_manager_v1", version: 3)
        state.recordGlobal(name: 3, interfaceName: "zxdg_output_manager_v1", version: 2)

        let global = state.firstGlobal(named: "zxdg_output_manager_v1")

        #expect(global?.name == 2)
        #expect(global?.advertisedVersion == RawVersion(3))
    }

    @Test
    func firstGlobalUsesLowestNameWhenDuplicateInterfacesHaveSameVersion() {
        let state = RegistryState()
        state.recordGlobal(name: 4, interfaceName: "wl_data_device_manager", version: 3)
        state.recordGlobal(name: 2, interfaceName: "wl_data_device_manager", version: 3)

        let global = state.firstGlobal(named: "wl_data_device_manager")

        #expect(global?.name == 2)
        #expect(global?.advertisedVersion == RawVersion(3))
    }

    @Test
    func removeNonExistentNameIsHarmless() {
        let state = RegistryState()
        state.removeGlobal(name: 99)
        #expect(state.snapshot.isEmpty)
    }
    @Test
    func recordGlobalOverwritesPreviousEntry() {
        let state = RegistryState()
        state.recordGlobal(name: 4, interfaceName: "wl_compositor", version: 3)
        state.recordGlobal(name: 4, interfaceName: "wl_compositor", version: 6)
        let global = state.firstGlobal(named: "wl_compositor")
        #expect(global?.advertisedVersion == RawVersion(6))
        #expect(state.snapshot.count == 1)
    }
    @Test
    func recordGlobalRejectsZeroVersion() {
        let state = RegistryState()
        #expect(!state.recordGlobal(name: 4, interfaceName: "wl_compositor", version: 0))
        #expect(state.snapshot.isEmpty)
        #expect(
            state.rejectedGlobals
                == [
                    RawGlobalAdvertisementRejection(
                        name: 4,
                        interfaceName: "wl_compositor",
                        advertisedVersion: RawVersion(0),
                        failure: .zeroAdvertisedVersion
                    )
                ]
        )
    }
    @Test
    func recordGlobalRejectsEmptyInterfaceName() {
        let state = RegistryState()
        #expect(!state.recordGlobal(name: 4, interfaceName: "", version: 1))
        #expect(state.snapshot.isEmpty)
        #expect(
            state.rejectedGlobals
                == [
                    RawGlobalAdvertisementRejection(
                        name: 4,
                        interfaceName: "",
                        advertisedVersion: RawVersion(1),
                        failure: .emptyInterfaceName
                    )
                ]
        )
    }
    @Test
    func recordGlobalRejectsInterfaceNameWithNUL() {
        let state = RegistryState()
        #expect(!state.recordGlobal(name: 4, interfaceName: "wl\0seat", version: 1))
        #expect(state.snapshot.isEmpty)
        #expect(
            state.rejectedGlobals
                == [
                    RawGlobalAdvertisementRejection(
                        name: 4,
                        interfaceName: "wl\0seat",
                        advertisedVersion: RawVersion(1),
                        failure: .interfaceNameContainsNUL
                    )
                ]
        )
    }
}
