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
