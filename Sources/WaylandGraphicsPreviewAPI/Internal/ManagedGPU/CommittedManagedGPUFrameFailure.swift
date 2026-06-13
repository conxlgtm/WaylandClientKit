import WaylandGPUPreview

package struct CommittedManagedGPUFrameFailure: Error, CustomStringConvertible {
    package let error: ManagedGPUPreviewBackingError

    package init(_ backingError: ManagedGPUPreviewBackingError) {
        error = backingError
    }

    package var failure: GPUBackingFailure {
        error.failure
    }

    package var description: String {
        error.description
    }
}
