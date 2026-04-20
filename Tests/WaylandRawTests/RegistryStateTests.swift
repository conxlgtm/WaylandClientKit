import Testing

@testable import WaylandRaw

@Suite
struct RegistryStateTests {
    @Test
    func recordsGlobal() {
        let state = RegistryState()
        state.recordGlobal(name: 4, interfaceName: "wl_compositor", version: 6)

        let global = state.firstGlobal(named: "wl_compositor")
        #expect(global != nil)
        #expect(global?.name == 4)
        #expect(global?.advertisedVersion == RawVersion(6))
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
}
