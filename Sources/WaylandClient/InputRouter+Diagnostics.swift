import WaylandRaw

extension InputRouter {
    func convert(_ diagnostic: RawInputDiagnostic) -> InputDiagnostic {
        InputDiagnostic(convert(diagnostic.payload))
    }

    func convert(_ payload: RawInputDiagnosticPayload) -> InputDiagnosticPayload {
        switch payload {
        case .keymap(let diagnostic):
            .keymap(convert(diagnostic))
        case .listener(let diagnostic):
            .listener(
                InputListenerDiagnostic(
                    listener: diagnostic.listener,
                    message: diagnostic.message
                )
            )
        case .queueOverflow(let overflow):
            .queueOverflow(convertRawOverflow(overflow))
        case .inputPipelineOverflow(let overflow):
            .inputPipelineOverflow(convertRawOverflow(overflow))
        }
    }

    func convert(_ diagnostic: RawKeymapDiagnostic) -> KeymapDiagnostic {
        switch diagnostic {
        case .readFailed(let error):
            .readFailed(convert(error))
        }
    }

    func convert(_ error: RawKeyboardKeymapReadError) -> KeymapReadFailure {
        switch error {
        case .unsupportedFormat(let format, let advertisedSize):
            .unsupportedFormat(
                format: KeyboardKeymapFormat(rawValue: format.rawValue),
                advertisedSize: advertisedSize
            )
        case .invalidFileDescriptor(let descriptor):
            .invalidFileDescriptor(descriptor)
        case .invalidSizeLimit(let maxSize, let hardMaximumSize):
            .invalidSizeLimit(maxSize: maxSize, hardMaximumSize: hardMaximumSize)
        case .emptyXKBV1Payload(let size):
            .emptyXKBV1Payload(size: size)
        case .tooLarge(let size, let maxSize):
            .tooLarge(size: size, maxSize: maxSize)
        case .tooLargeForProtocolSize(let byteCount):
            .tooLargeForProtocolSize(byteCount)
        case .fdTooSmall(let size, let actualSize):
            .fdTooSmall(size: size, actualSize: actualSize)
        case .missingNULTerminator(let size):
            .missingNULTerminator(size: size)
        case .system(let errno, let operation):
            .system(errno: errno, operation: convert(operation))
        }
    }

    func convert(_ operation: RawKeyboardKeymapReadOperation) -> KeymapReadOperation {
        switch operation {
        case .fstat:
            .fstat
        case .mmap:
            .mmap
        }
    }

    func convert(_ operation: RawInputDiagnosticOperation) -> InputDiagnosticOperation {
        switch operation {
        case .keyboardKeymap:
            .keyboardKeymap
        case .listener(let name):
            .listener(name)
        case .queueOverflow:
            .queueOverflow
        case .inputPipelineOverflow(let overflow):
            .inputPipelineOverflow(convertRawOverflow(overflow))
        }
    }

    func convertRawOverflow(_ overflow: RawInputPipelineOverflow) -> InputPipelineOverflow {
        InputPipelineOverflow(
            stage: .rawInputQueue,
            capacity: overflow.capacity
        )
    }
}
