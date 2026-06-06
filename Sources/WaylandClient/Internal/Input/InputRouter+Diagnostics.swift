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
        case .seatBinding(let diagnostic):
            .seatBinding(
                InputSeatBindingDiagnostic(
                    interface: diagnostic.interface,
                    failure: convert(diagnostic.failure)
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

    func convert(_ failure: RawSeatBindingFailure) -> InputSeatBindingFailure {
        switch failure {
        case .bindFailed(let interface):
            .bindFailed(interface: interface)
        case .listener(let listener):
            .listener(convert(listener))
        case .proxy(let error):
            convert(error)
        case .system(let error):
            .system(WaylandSystemError(error))
        case .systemErrnoUnavailable(let operation):
            .systemErrnoUnavailable(WaylandSystemOperation(operation))
        case .other(let message):
            .other(message)
        }
    }

    func convert(_ listener: RawListenerInstallationError) -> InputSeatBindingListener {
        switch listener {
        case .registry:
            .registry
        case .output:
            .output
        case .seat:
            .seat
        case .pointer:
            .pointer
        case .keyboard:
            .keyboard
        case .touch:
            .touch
        case .syncCallback:
            .syncCallback
        }
    }

    func convert(_ error: RawProxyError) -> InputSeatBindingFailure {
        switch error {
        case .queueMismatch(let interface, let objectID):
            .proxyQueueMismatch(interface: interface, objectID: objectID?.value)
        }
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
                format: KeyboardKeymapFormat(format),
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

    func convertRawOverflow(_ overflow: RawInputPipelineOverflow) -> InputPipelineOverflow {
        InputPipelineOverflow(
            stage: .rawInputQueue,
            capacity: InputPipelineCapacity(unchecked: overflow.capacity.rawValue)
        )
    }
}
