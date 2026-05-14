import CDRMSystem
import CGBMSystem
import Testing

@Suite
struct GraphicsSystemImportTests {
    @Test
    func gbmSystemSymbolsImportIntoSwift() {
        let createDevice = unsafe gbm_create_device
        let boCreate = unsafe gbm_bo_create
        let boDestroy = unsafe gbm_bo_destroy

        #expect(unsafe MemoryLayout.size(ofValue: createDevice) > 0)
        #expect(unsafe MemoryLayout.size(ofValue: boCreate) > 0)
        #expect(unsafe MemoryLayout.size(ofValue: boDestroy) > 0)
    }

    @Test
    func drmSystemSymbolsImportIntoSwift() {
        let getDevices2 = unsafe drmGetDevices2
        let freeDevices = unsafe drmFreeDevices

        #expect(unsafe MemoryLayout.size(ofValue: getDevices2) > 0)
        #expect(unsafe MemoryLayout.size(ofValue: freeDevices) > 0)
    }
}
