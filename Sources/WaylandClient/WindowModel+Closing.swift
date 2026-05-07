extension WindowModel {
    mutating func reduceCompositorCloseRequested(
        policy: CloseRequestPolicy
    ) throws -> [WindowEffect] {
        guard !isDestroyed else {
            throw ClientError.window(id, .invalidLifecycleTransition(.closeAfterDestroyed))
        }

        switch policy {
        case .requestOnly:
            return reduceRequestOnlyCompositorCloseRequested()
        case .autoClose:
            guard case .active(var activeState) = lifecycle else {
                return try beginClosing(reason: .compositorRequest, publishRequest: true)
            }

            guard activeState.closeRequest == .none else {
                return []
            }

            activeState.closeRequest = .requested
            lifecycle = .active(activeState)

            return try beginClosing(reason: .compositorRequest, publishRequest: true)
        }
    }

    private mutating func reduceRequestOnlyCompositorCloseRequested() -> [WindowEffect] {
        switch lifecycle {
        case .created(let closeRequest):
            guard closeRequest == .none else { return [] }
            lifecycle = .created(.requested)
        case .roleAssigned(let closeRequest):
            guard closeRequest == .none else { return [] }
            lifecycle = .roleAssigned(.requested)
        case .waitingForInitialConfigure(let closeRequest):
            guard closeRequest == .none else { return [] }
            lifecycle = .waitingForInitialConfigure(.requested)
        case .active(var activeState):
            guard activeState.closeRequest == .none else { return [] }
            activeState.closeRequest = .requested
            lifecycle = .active(activeState)
        case .closing, .destroyed:
            return []
        }

        return closeRequestEffects()
    }

    mutating func beginClosing(
        reason: ClosingReason,
        publishRequest: Bool
    ) throws -> [WindowEffect] {
        switch lifecycle {
        case .destroyed:
            return []
        case .closing:
            return []
        case .created, .roleAssigned, .waitingForInitialConfigure, .active:
            break
        }

        lifecycle = .closing(
            ClosingWindowState(
                reason: reason
            )
        )

        var effects: [WindowEffect] = []
        if publishRequest {
            effects.append(contentsOf: closeRequestEffects())
        }
        effects.append(contentsOf: [
            .cancelFrameCallback,
            .retireSwapchain,
            .destroyRoleObjects,
            .destroySurface,
        ])

        if case .published(let windowID) = publication {
            effects.append(.publishClosed(windowID))
            publication = .closedPublished(windowID)
        }

        lifecycle = .destroyed
        return effects
    }

    private func closeRequestEffects() -> [WindowEffect] {
        guard case .published(let windowID) = publication else {
            return []
        }

        return [.publishCloseRequested(windowID)]
    }
}
