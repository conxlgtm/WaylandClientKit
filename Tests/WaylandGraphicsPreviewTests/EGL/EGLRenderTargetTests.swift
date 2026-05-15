import CEGLShims
import Glibc
import Testing

@testable import WaylandGraphicsPreview
@testable import WaylandRaw

@Suite
struct EGLRenderTargetTests {
    @Test
    func gbmPlatformExtensionDetectionRequiresNamedExtension() {
        #expect(EGLGBMRenderTarget.supportsGBMPlatform(clientExtensions: "EGL_KHR_platform_gbm"))
        #expect(EGLGBMRenderTarget.supportsGBMPlatform(clientExtensions: "EGL_MESA_platform_gbm"))
        #expect(
            EGLGBMRenderTarget.supportsGBMPlatform(
                clientExtensions: "EGL_EXT_platform_base EGL_KHR_surfaceless_context"
            ) == false
        )
        #expect(EGLGBMRenderTarget.supportsGBMPlatform(clientExtensions: nil) == false)
    }

    @Test
    func gpuSmokeDrawsDeterministicPixelWhenEnabled() throws {
        guard
            let smokeFlag = unsafe Glibc.getenv("SWL_RUN_GPU_SMOKE"),
            unsafe String(cString: smokeFlag) == "1"
        else {
            return
        }
        guard let path = firstRenderNodePath() else {
            return
        }

        let fd = unsafe path.withCString { pathPointer in
            unsafe Glibc.open(pathPointer, O_RDWR | O_CLOEXEC)
        }
        guard fd >= 0 else {
            return
        }

        let renderNode = try GBMRenderNodeFileDescriptor(adopting: fd)
        let device = try GBMDevice(adoptingRenderNodeFileDescriptor: renderNode)
        let size = try GBMBufferSize(width: 16, height: 16)
        let descriptor = GBMSurfaceDescriptor(
            size: size,
            formatModifier: RawLinuxDmabufFormatModifier(
                format: GBMDRMFormat.xrgb8888,
                modifier: GBMDRMModifier.invalid
            ),
            flags: .rendering
        )
        let target = try EGLGBMRenderTarget(
            device: device,
            surfaceDescriptor: descriptor
        )

        let pixel = try target.drawClear(
            red: 1,
            green: 0,
            blue: 0,
            alpha: 1
        )
        let lockedBuffer = try target.lockFrontBuffer()
        let exportedBuffer = try lockedBuffer.exportDmabuf()

        #expect(pixel.red >= 250)
        #expect(pixel.green <= 5)
        #expect(pixel.blue <= 5)
        #expect(exportedBuffer.width == 16)
        #expect(exportedBuffer.height == 16)
    }

    @Test
    func drawClearReportsClearCurrentFailure() throws {
        let display = try unsafe #require(UnsafeMutableRawPointer(bitPattern: 0xE001))
        let surface = try unsafe #require(UnsafeMutableRawPointer(bitPattern: 0xE002))
        let context = try unsafe #require(UnsafeMutableRawPointer(bitPattern: 0xE003))
        let size = try GBMBufferSize(width: 16, height: 16)
        let eglContextLost: Int32 = 0x300E

        swl_test_egl_draw_recording_begin(-1, eglContextLost)
        defer {
            swl_test_egl_draw_recording_end()
        }

        do {
            _ = try unsafe EGLGBMRenderTarget.testingDrawClear(
                display: display,
                surface: surface,
                context: context,
                size: size
            )
            Issue.record("drawClear should report clear-current failure")
        } catch {
            #expect(error == .clearCurrentFailed(eglError: eglContextLost))
        }
        let record = unsafe swl_test_egl_draw_record()
        let makeCurrentCallCount = unsafe record.make_current_call_count
        let clearCallCount = unsafe record.clear_call_count
        let readPixelCallCount = unsafe record.read_pixel_call_count
        let swapBuffersCallCount = unsafe record.swap_buffers_call_count
        let clearCurrentCallCount = unsafe record.clear_current_call_count

        #expect(makeCurrentCallCount == 1)
        #expect(clearCallCount == 1)
        #expect(readPixelCallCount == 1)
        #expect(swapBuffersCallCount == 1)
        #expect(clearCurrentCallCount == 1)
    }

    private func firstRenderNodePath() -> String? {
        for index in 128..<192 {
            let path = "/dev/dri/renderD\(index)"
            let isAccessible = unsafe path.withCString { pathPointer in
                unsafe Glibc.access(pathPointer, R_OK | W_OK)
            }
            if isAccessible == 0 {
                return path
            }
        }

        return nil
    }
}
