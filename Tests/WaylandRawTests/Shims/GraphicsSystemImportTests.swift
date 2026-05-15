import CDRMSystem
import CEGLSystem
import CGBMSystem
import CGLESv2System
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

    @Test
    func eglSystemSymbolsImportIntoSwift() {
        let getDisplay = unsafe eglGetDisplay
        let initialize = unsafe eglInitialize
        let terminate = unsafe eglTerminate

        #expect(unsafe MemoryLayout.size(ofValue: getDisplay) > 0)
        #expect(unsafe MemoryLayout.size(ofValue: initialize) > 0)
        #expect(unsafe MemoryLayout.size(ofValue: terminate) > 0)
    }

    @Test
    func glesv2SystemSymbolsImportIntoSwift() {
        let clear = glClear
        let viewport = glViewport
        let readPixels = unsafe glReadPixels

        #expect(MemoryLayout.size(ofValue: clear) > 0)
        #expect(MemoryLayout.size(ofValue: viewport) > 0)
        #expect(unsafe MemoryLayout.size(ofValue: readPixels) > 0)
    }
}
