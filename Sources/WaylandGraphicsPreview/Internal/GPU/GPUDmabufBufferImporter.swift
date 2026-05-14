import Glibc
import WaylandRaw

package struct GPUDmabufBufferImportDescriptor: Equatable, Sendable {
    package let width: Int32
    package let height: Int32
    package let format: UInt32
    package let modifier: UInt64
    package let planeCount: Int
}

package enum GPUDmabufBufferImportState: Equatable, Sendable {
    case createRequested
    case created
    case failed
    case destroyed
}

package enum GPUDmabufBufferImportError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyPlaneSet
    case dimensionsExceedInt32(width: UInt32, height: UInt32)
    case planeCountExceedsUInt32(Int)
    case planeLayoutFailed(index: Int, GBMAllocationError)
    case planeFileDescriptorFailed(index: Int, GBMAllocationError)
    case addPlaneFailed(index: Int, RuntimeError)
    case createRequestFailed(RuntimeError)
    case compositorImportFailed
    case useAfterTerminalState(GPUDmabufBufferImportState)

    package var description: String {
        switch self {
        case .emptyPlaneSet:
            "GPU dmabuf import requires at least one plane"
        case .dimensionsExceedInt32(let width, let height):
            "GPU dmabuf dimensions \(width)x\(height) exceed Int32"
        case .planeCountExceedsUInt32(let planeCount):
            "GPU dmabuf plane count \(planeCount) exceeds UInt32"
        case .planeLayoutFailed(let index, let error):
            "GPU dmabuf plane \(index) layout failed: \(error.description)"
        case .planeFileDescriptorFailed(let index, let error):
            "GPU dmabuf plane \(index) fd transfer failed: \(error.description)"
        case .addPlaneFailed(let index, let error):
            "GPU dmabuf plane \(index) add request failed: \(error.description)"
        case .createRequestFailed(let error):
            "GPU dmabuf create request failed: \(error.description)"
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

    private init(
        params bufferParams: RawLinuxDmabufBufferParams,
        onCreated handleCreated: @escaping (RawLinuxDmabufBuffer) -> Void,
        onFailure handleFailure: @escaping (GPUDmabufBufferImportError) -> Void
    ) {
        params = bufferParams
        onCreated = handleCreated
        onFailure = handleFailure
    }

    package static func requestImport(
        export: GBMDmabufExport,
        linuxDmabuf: RawLinuxDmabuf,
        flags: RawLinuxDmabufBufferParamsFlags = [],
        onCreated handleCreated: @escaping (RawLinuxDmabufBuffer) -> Void,
        onFailure handleFailure: @escaping (GPUDmabufBufferImportError) -> Void
    ) throws(GPUDmabufBufferImportError) -> GPUDmabufBufferImport {
        let descriptor = try importDescriptor(for: export)

        let requestBox = GPUDmabufBufferImportBox()
        let params: RawLinuxDmabufBufferParams
        do {
            params = try linuxDmabuf.createBufferParams { event in
                requestBox.importRequest?.handle(event)
            } onFailure: { error in
                requestBox.importRequest?.handleFailure(.createRequestFailed(error))
            }
        } catch {
            throw GPUDmabufBufferImportError.createRequestFailed(runtimeError(from: error))
        }

        let importRequest = GPUDmabufBufferImport(
            params: params,
            onCreated: handleCreated,
            onFailure: handleFailure
        )
        requestBox.importRequest = importRequest

        try addPlanes(from: export, descriptor: descriptor, to: params)

        do {
            try params.create(
                width: descriptor.width,
                height: descriptor.height,
                format: descriptor.format,
                flags: flags
            )
        } catch {
            throw GPUDmabufBufferImportError.createRequestFailed(runtimeError(from: error))
        }

        return importRequest
    }

    private static func addPlanes(
        from export: GBMDmabufExport,
        descriptor: GPUDmabufBufferImportDescriptor,
        to params: RawLinuxDmabufBufferParams
    ) throws(GPUDmabufBufferImportError) {
        for index in 0..<descriptor.planeCount {
            let layout: GBMDmabufPlaneLayout
            do {
                layout = try export.planeLayout(at: index)
            } catch {
                throw GPUDmabufBufferImportError.planeLayoutFailed(index: index, error)
            }

            var planeDescriptor: RawLinuxDmabufPlaneFileDescriptor
            do {
                planeDescriptor = try export.takePlaneFileDescriptor(at: index)
            } catch {
                throw GPUDmabufBufferImportError.planeFileDescriptorFailed(
                    index: index,
                    error
                )
            }

            do {
                try params.addPlane(
                    fileDescriptor: &planeDescriptor,
                    planeIndex: UInt32(index),
                    offset: layout.offset,
                    stride: layout.stride,
                    modifier: export.modifier
                )
            } catch {
                planeDescriptor.close()
                throw GPUDmabufBufferImportError.addPlaneFailed(
                    index: index,
                    runtimeError(from: error)
                )
            }
        }
    }

    package static func importDescriptor(
        for export: GBMDmabufExport
    ) throws(GPUDmabufBufferImportError) -> GPUDmabufBufferImportDescriptor {
        guard export.planeCount > 0 else {
            throw GPUDmabufBufferImportError.emptyPlaneSet
        }
        guard export.planeCount <= Int(UInt32.max) else {
            throw GPUDmabufBufferImportError.planeCountExceedsUInt32(export.planeCount)
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
        guard stateStorage != .destroyed else { return }

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

    private func handle(_ event: RawLinuxDmabufBufferParamsEvent) {
        guard stateStorage == .createRequested else {
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
        guard stateStorage == .createRequested else { return }

        stateStorage = .failed
        params = nil
        onFailure?(error)
    }

    private static func runtimeError(from error: any Error) -> RuntimeError {
        if let runtimeError = error as? RuntimeError {
            return runtimeError
        }

        return RuntimeError.systemError(
            errno: EINVAL,
            operation: .validateArgument(String(describing: error))
        )
    }
}

@safe
private final class GPUDmabufBufferImportBox {
    weak var importRequest: GPUDmabufBufferImport?
}
