import WaylandGraphicsCore
import WaylandRaw

package final class ManagedGPUPreviewBuffer: GPUWindowPresenterBuffer {
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
        releaseObserver = observer
        buffer.setReleaseObserver { [weak self] in
            self?.handleRelease()
        }
    }

    package func destroy() {
        releaseObserver = nil
        lockedBuffer?.release()
        lockedBuffer = nil
        renderTarget = nil
        buffer.destroy()
    }

    deinit {
        destroy()
    }

    private func handleRelease() {
        lockedBuffer?.release()
        lockedBuffer = nil
        renderTarget = nil
        releaseObserver?()
    }
}
