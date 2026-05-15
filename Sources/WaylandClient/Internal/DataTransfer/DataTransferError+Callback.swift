extension DataTransferError {
    package init(callbackBackendError error: any Error) {
        if let dataTransferError = error as? DataTransferError {
            self = dataTransferError
        } else {
            self = .callbackFailure(.backend(error))
        }
    }
}

extension DataTransferCallbackFailureCause {
    package static func backend(_ error: any Error) -> Self {
        .backend(
            type: String(describing: type(of: error)),
            description: String(describing: error)
        )
    }
}
