import Foundation
import WaylandGraphicsCore
import WaylandRaw

package final class ManagedGPUPreviewBuffer: GPUWindowPresenterBuffer {
    private let lock = NSLock()
    private let buffer: RawLinuxDmabufBuffer
    private var lockedBuffer: GBMLockedSurfaceBuffer?
    private var renderTarget: EGLGBMRenderTarget?
    private var releaseObserver: (() -> Void)?

    package init(
        buffer importedBuffer: RawLinuxDmabufBuffer,
        lockedBuffer importedLockedBuffer: GBMLockedSurfaceBuffer,
        renderTarget importedRenderTarget: EGLGBMRenderTarget
    ) {
        buffer = importedBuffer
        lockedBuffer = importedLockedBuffer
        renderTarget = importedRenderTarget
    }

    package var surfaceBuffer: RawSurfaceBuffer {
        buffer.surfaceBuffer
    }

    package func setReleaseObserver(_ observer: @escaping () -> Void) {
        lock.lock()
        releaseObserver = observer
        lock.unlock()
        buffer.setReleaseObserver { [weak self] in
            self?.handleRelease()
        }
    }

    package func destroy() {
        _ = releaseResources(clearObserver: true)
        buffer.destroy()
    }

    deinit {
        destroy()
    }

    private func handleRelease() {
        let observer = releaseResources(clearObserver: false)
        observer?()
    }

    private func releaseResources(clearObserver: Bool) -> (() -> Void)? {
        lock.lock()
        defer { lock.unlock() }

        let observer = releaseObserver
        if clearObserver {
            releaseObserver = nil
        }
        lockedBuffer?.release()
        lockedBuffer = nil
        renderTarget = nil
        return observer
    }
}
