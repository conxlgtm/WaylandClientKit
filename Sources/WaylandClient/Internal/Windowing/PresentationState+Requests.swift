protocol GeneratedPresentationRequest: Equatable, Sendable {
    var generation: UInt64 { get }
}

extension PresentationRequest: GeneratedPresentationRequest {}
extension PopupPresentationRequest: GeneratedPresentationRequest {}

extension PresentationState where Request: GeneratedPresentationRequest {
    var isIdle: Bool {
        self == .idle
    }

    var requestedRequest: Request? {
        guard case .requested(let request) = self else {
            return nil
        }

        return request
    }

    var drawingRequest: Request? {
        guard case .drawing(let request) = self else {
            return nil
        }

        return request
    }

    var drawingGeneration: UInt64? {
        drawingRequest?.generation
    }
}
