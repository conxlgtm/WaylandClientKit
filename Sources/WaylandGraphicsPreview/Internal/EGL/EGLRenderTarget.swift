import CEGLShims
import CGBMShims
import Glibc
import WaylandRaw

package struct EGLVersion: Equatable, Sendable {
    package let major: Int32
    package let minor: Int32
}

package struct EGLRGBA8Pixel: Equatable, Sendable {
    package let red: UInt8
    package let green: UInt8
    package let blue: UInt8
    package let alpha: UInt8
}

package enum EGLRenderError: Error, Equatable, Sendable, CustomStringConvertible {
    case gbmPlatformUnavailable(clientExtensions: String?)
    case displayCreationFailed(errno: Int32, eglError: Int32)
    case displayInitializeFailed(eglError: Int32)
    case bindGLESFailed(eglError: Int32)
    case configSelectionFailed(eglError: Int32)
    case contextCreationFailed(eglError: Int32)
    case surfaceCreationFailed(eglError: Int32)
    case makeCurrentFailed(eglError: Int32)
    case clearCurrentFailed(eglError: Int32)
    case swapBuffersFailed(eglError: Int32)
    case clearFailed(glError: UInt32)
    case readPixelFailed(glError: UInt32)
    case targetDestroyed

    package var description: String {
        switch self {
        case .gbmPlatformUnavailable(let clientExtensions):
            "EGL GBM platform support unavailable in client extensions "
                + "\(clientExtensions ?? "<none>")"
        case .displayCreationFailed(let errorNumber, let eglError):
            "EGL GBM display creation failed with errno \(errorNumber), "
                + "EGL error \(eglError)"
        case .displayInitializeFailed(let eglError):
            "EGL display initialize failed with EGL error \(eglError)"
        case .bindGLESFailed(let eglError):
            "EGL OpenGL ES API bind failed with EGL error \(eglError)"
        case .configSelectionFailed(let eglError):
            "EGL GLES window config selection failed with EGL error \(eglError)"
        case .contextCreationFailed(let eglError):
            "EGL GLES2 context creation failed with EGL error \(eglError)"
        case .surfaceCreationFailed(let eglError):
            "EGL window surface creation failed with EGL error \(eglError)"
        case .makeCurrentFailed(let eglError):
            "EGL make-current failed with EGL error \(eglError)"
        case .clearCurrentFailed(let eglError):
            "EGL clear-current failed with EGL error \(eglError)"
        case .swapBuffersFailed(let eglError):
            "EGL swap-buffers failed with EGL error \(eglError)"
        case .clearFailed(let glError):
            "GLES clear failed with GL error \(glError)"
        case .readPixelFailed(let glError):
            "GLES read-pixel failed with GL error \(glError)"
        case .targetDestroyed:
            "EGL render target was already destroyed"
        }
    }
}

@safe
package final class EGLGBMRenderTarget {
    private let gbmSurface: GBMSurface
    private var display: UnsafeMutableRawPointer?
    private var context: UnsafeMutableRawPointer?
    private var surface: UnsafeMutableRawPointer?

    private let renderSize: GBMBufferSize
    package private(set) var version = EGLVersion(major: 0, minor: 0)

    @safe
    package init(
        device: GBMDevice,
        surfaceDescriptor: GBMSurfaceDescriptor
    ) throws {
        let clientExtensions = Self.clientExtensions()
        guard Self.supportsGBMPlatform(clientExtensions: clientExtensions) else {
            throw EGLRenderError.gbmPlatformUnavailable(
                clientExtensions: clientExtensions
            )
        }

        gbmSurface = try GBMSurface(
            device: device,
            descriptor: surfaceDescriptor
        )
        renderSize = surfaceDescriptor.size

        let displayPointer = try device.withUnsafeDevicePointer { devicePointer in
            unsafe swl_egl_display_for_gbm_device(devicePointer)
        }
        guard let displayPointer = unsafe displayPointer else {
            throw EGLRenderError.displayCreationFailed(
                errno: errno > 0 ? errno : ENODEV,
                eglError: swl_egl_error()
            )
        }
        unsafe display = displayPointer

        var major: Int32 = 0
        var minor: Int32 = 0
        guard unsafe swl_egl_initialize(displayPointer, &major, &minor) == 0 else {
            destroy()
            throw EGLRenderError.displayInitializeFailed(eglError: swl_egl_error())
        }
        version = EGLVersion(major: major, minor: minor)

        guard swl_egl_bind_gles_api() == 0 else {
            destroy()
            throw EGLRenderError.bindGLESFailed(eglError: swl_egl_error())
        }

        guard
            let config = unsafe swl_egl_choose_gles_window_config(
                displayPointer,
                surfaceDescriptor.format
            )
        else {
            destroy()
            throw EGLRenderError.configSelectionFailed(eglError: swl_egl_error())
        }

        guard
            let contextPointer = unsafe swl_egl_create_gles2_context(
                displayPointer,
                config
            )
        else {
            destroy()
            throw EGLRenderError.contextCreationFailed(eglError: swl_egl_error())
        }
        unsafe context = contextPointer

        let surfacePointer = try gbmSurface.withUnsafeSurfacePointer { gbmSurfacePointer in
            unsafe swl_egl_create_window_surface(
                displayPointer,
                config,
                gbmSurfacePointer
            )
        }
        guard let surfacePointer = unsafe surfacePointer else {
            destroy()
            throw EGLRenderError.surfaceCreationFailed(eglError: swl_egl_error())
        }
        unsafe surface = surfacePointer
    }

    package func drawClear(
        red: Float,
        green: Float,
        blue: Float,
        alpha: Float
    ) throws(EGLRenderError) -> EGLRGBA8Pixel {
        let handles = try liveHandles()
        guard unsafe swl_egl_make_current(
            handles.display,
            handles.surface,
            handles.context
        ) == 0 else {
            throw EGLRenderError.makeCurrentFailed(eglError: swl_egl_error())
        }
        defer {
            _ = unsafe swl_egl_clear_current(handles.display)
        }

        let size = handles.size
        guard swl_gles2_clear_rgba(size.width, size.height, red, green, blue, alpha) == 0 else {
            throw EGLRenderError.clearFailed(glError: swl_gles2_error())
        }

        var pixelBytes = [UInt8](repeating: 0, count: 4)
        guard unsafe pixelBytes.withUnsafeMutableBufferPointer({ pointer in
            unsafe swl_gles2_read_center_pixel_rgba8(
                size.width,
                size.height,
                pointer.baseAddress
            )
        }) == 0 else {
            throw EGLRenderError.readPixelFailed(glError: swl_gles2_error())
        }

        guard unsafe swl_egl_swap_buffers(handles.display, handles.surface) == 0 else {
            throw EGLRenderError.swapBuffersFailed(eglError: swl_egl_error())
        }

        return EGLRGBA8Pixel(
            red: pixelBytes[0],
            green: pixelBytes[1],
            blue: pixelBytes[2],
            alpha: pixelBytes[3]
        )
    }

    package func lockFrontBuffer() throws(GBMAllocationError) -> GBMLockedSurfaceBuffer {
        try gbmSurface.lockFrontBuffer()
    }

    package func destroy() {
        let displayPointer = unsafe display
        let contextPointer = unsafe context
        let surfacePointer = unsafe surface

        unsafe self.surface = nil
        unsafe self.context = nil
        unsafe self.display = nil

        if let displayPointer = unsafe displayPointer,
           let surfacePointer = unsafe surfacePointer
        {
            unsafe swl_egl_destroy_surface(displayPointer, surfacePointer)
        }
        if let displayPointer = unsafe displayPointer,
           let contextPointer = unsafe contextPointer
        {
            unsafe swl_egl_destroy_context(displayPointer, contextPointer)
        }
        if let displayPointer = unsafe displayPointer {
            unsafe swl_egl_terminate(displayPointer)
        }
        gbmSurface.destroy()
    }

    deinit {
        destroy()
    }

    @safe
    private struct LiveHandles {
        let display: UnsafeMutableRawPointer
        let context: UnsafeMutableRawPointer
        let surface: UnsafeMutableRawPointer
        let size: GBMBufferSize
    }

    private func liveHandles() throws(EGLRenderError) -> LiveHandles {
        guard let display = unsafe display,
              let context = unsafe context,
              let surface = unsafe surface
        else {
            throw EGLRenderError.targetDestroyed
        }

        return unsafe LiveHandles(
            display: display,
            context: context,
            surface: surface,
            size: renderSize
        )
    }

    private static func clientExtensions() -> String? {
        guard let extensions = unsafe swl_egl_query_client_extensions() else {
            return nil
        }

        return unsafe String(cString: extensions)
    }

    package static func supportsGBMPlatform(
        clientExtensions extensions: String?
    ) -> Bool {
        guard let extensions else { return false }

        return extensions.split(separator: " ").contains("EGL_KHR_platform_gbm")
            || extensions.split(separator: " ").contains("EGL_MESA_platform_gbm")
    }
}
