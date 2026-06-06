import WaylandRaw

package struct GPUDmabufBufferImportDescriptor: Equatable, Sendable {
    package let width: Int32
    package let height: Int32
    package let format: UInt32
    package let modifier: UInt64
    package let planeCount: Int

    package var planeIndices: Range<Int> {
        0..<planeCount
    }
}

package enum GPUDmabufBufferImportState: Equatable, Sendable {
    case createRequested
    case created
    case failed
    case destroyed

    package var acceptsCompositorEvent: Bool {
        self == .createRequested
    }

    package var isDestroyed: Bool {
        self == .destroyed
    }

    package var isTerminal: Bool {
        switch self {
        case .created, .failed, .destroyed:
            true
        case .createRequested:
            false
        }
    }
}

package enum GPUDmabufBufferImportError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyPlaneSet
    case dimensionsExceedInt32(width: UInt32, height: UInt32)
    case compositorImportFailed
    case useAfterTerminalState(GPUDmabufBufferImportState)

    package var description: String {
        switch self {
        case .emptyPlaneSet:
            "GPU dmabuf import requires at least one plane"
        case .dimensionsExceedInt32(let width, let height):
            "GPU dmabuf dimensions \(width)x\(height) exceed Int32"
        case .compositorImportFailed:
            "GPU dmabuf import failed in compositor"
        case .useAfterTerminalState(let state):
            "GPU dmabuf import used after \(state)"
        }
    }
}

@safe
package final class GPUDmabufBufferImport {
    private var params: RawLinuxDmabufBufferParams?
    private var importedBuffer: RawLinuxDmabufBuffer?
    private var stateStorage = GPUDmabufBufferImportState.createRequested
    private var onCreated: ((RawLinuxDmabufBuffer) -> Void)?
    private var onFailure: ((GPUDmabufBufferImportError) -> Void)?

    package var state: GPUDmabufBufferImportState {
        stateStorage
    }

    package var buffer: RawLinuxDmabufBuffer? {
        importedBuffer
    }

    package init(
        testingInitialState initialState: GPUDmabufBufferImportState,
        onCreated handleCreated: @escaping (RawLinuxDmabufBuffer) -> Void,
        onFailure handleFailure: @escaping (GPUDmabufBufferImportError) -> Void
    ) {
        params = nil
        stateStorage = initialState
        onCreated = handleCreated
        onFailure = handleFailure
    }

    package static func importDescriptor(
        for export: GBMDmabufExport
    ) throws(GPUDmabufBufferImportError) -> GPUDmabufBufferImportDescriptor {
        guard export.planeCount > 0 else {
            throw GPUDmabufBufferImportError.emptyPlaneSet
        }
        guard
            export.width <= UInt32(Int32.max),
            export.height <= UInt32(Int32.max)
        else {
            throw GPUDmabufBufferImportError.dimensionsExceedInt32(
                width: export.width,
                height: export.height
            )
        }

        return GPUDmabufBufferImportDescriptor(
            width: Int32(export.width),
            height: Int32(export.height),
            format: export.format,
            modifier: export.modifier,
            planeCount: export.planeCount
        )
    }

    package func destroy() {
        guard !stateStorage.isDestroyed else { return }

        stateStorage = .destroyed
        params?.destroy()
        params = nil
        importedBuffer = nil
        onCreated = nil
        onFailure = nil
    }

    deinit {
        destroy()
    }

    package func testingHandle(_ event: RawLinuxDmabufBufferParamsEvent) {
        handle(event)
    }

    private func handle(_ event: RawLinuxDmabufBufferParamsEvent) {
        guard stateStorage.acceptsCompositorEvent else {
            handleFailure(.useAfterTerminalState(stateStorage))
            return
        }

        switch event {
        case .created(let buffer):
            stateStorage = .created
            params = nil
            importedBuffer = buffer
            onCreated?(buffer)
        case .failed:
            handleFailure(.compositorImportFailed)
        }
    }

    private func handleFailure(_ error: GPUDmabufBufferImportError) {
        if stateStorage.acceptsCompositorEvent {
            stateStorage = .failed
            params = nil
        }
        onFailure?(error)
    }
}
