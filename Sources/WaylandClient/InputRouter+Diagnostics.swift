import WaylandRaw

extension InputRouter {
    func convert(_ diagnostic: RawInputDiagnostic) -> InputDiagnostic {
        InputDiagnostic(convert(diagnostic.payload))
    }

    func convert(_ payload: RawInputDiagnosticPayload) -> InputDiagnosticPayload {
        switch payload {
        case .keymap(let diagnostic):
            .keymap(convert(diagnostic))
        case .keyboardRepeat(let diagnostic):
            .keyboardRepeat(convert(diagnostic))
        case .listener(let diagnostic):
            .listener(
                InputListenerDiagnostic(
                    listener: diagnostic.listener,
                    message: diagnostic.message
                )
            )
        case .inputPipelineOverflow(let overflow):
            .inputPipelineOverflow(convertRawOverflow(overflow))
        }
    }

    func convert(_ diagnostic: RawKeymapDiagnostic) -> KeymapDiagnostic {
        switch diagnostic {
        case .readFailed(_, let error):
            .readFailed(convert(error))
        }
    }

    func convert(_ diagnostic: RawKeyboardRepeatDiagnostic) -> KeyboardRepeatDiagnostic {
        KeyboardRepeatDiagnostic(convert(diagnostic.error))
    }

    func convert(_ error: RawKeyboardRepeatInfoError) -> KeyboardRepeatFailure {
        switch error {
        case .negativeRate(let rate, let delay):
            .negativeRate(rate: rate, delay: delay)
        case .negativeDelay(let rate, let delay):
            .negativeDelay(rate: rate, delay: delay)
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
        case .system(let error):
            .system(WaylandSystemError(error))
        }
    }

    func convert(_ operation: RawInputDiagnosticOperation) -> InputDiagnosticOperation {
        switch operation {
        case .keyboardKeymap:
            .keyboardKeymap
        case .keyboardRepeat:
            .keyboardRepeat
        case .listener(let name):
            .listener(name)
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
