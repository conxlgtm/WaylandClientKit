extension DataOfferID {
    package init(_ identity: ClipboardOfferIdentity) {
        self.init(rawValue: identity.rawValue)
    }

    package init(_ identity: PrimarySelectionOfferIdentity) {
        self.init(rawValue: identity.rawValue)
    }

    package init(_ identity: DragOfferIdentity) {
        self.init(rawValue: identity.rawValue)
    }

    package var clipboardIdentity: ClipboardOfferIdentity {
        ClipboardOfferIdentity(self)
    }

    package var primarySelectionIdentity: PrimarySelectionOfferIdentity {
        PrimarySelectionOfferIdentity(self)
    }

    package var dragIdentity: DragOfferIdentity {
        DragOfferIdentity(self)
    }
}

extension DataSourceID {
    package init(_ identity: ClipboardSourceIdentity) {
        self.init(rawValue: identity.rawValue)
    }

    package init(_ identity: PrimarySelectionSourceIdentity) {
        self.init(rawValue: identity.rawValue)
    }

    package init(_ identity: DragSourceIdentity) {
        self.init(rawValue: identity.rawValue)
    }

    package var clipboardIdentity: ClipboardSourceIdentity {
        ClipboardSourceIdentity(self)
    }

    package var primarySelectionIdentity: PrimarySelectionSourceIdentity {
        PrimarySelectionSourceIdentity(self)
    }

    package var dragIdentity: DragSourceIdentity {
        DragSourceIdentity(self)
    }
}

extension DataTransferEvent {
    package var cancelledWriteSource: DataTransferSourceWriteSource? {
        switch self {
        case .clipboardSourceCancelled(let source):
            .clipboard(DataSourceID(source))
        case .primarySelectionSourceCancelled(let source):
            .primarySelection(DataSourceID(source))
        case .dragSourceCancelled(let source):
            .dragAndDrop(DataSourceID(source))
        case .clipboardSelectionChanged, .primarySelectionChanged, .sourceSendRequested,
            .sourceWriteSucceeded,
            .dragSourceTargetChanged, .dragSourceActionChanged, .dragSourceDropPerformed,
            .dragSourceFinished, .dragEntered, .dragMotion, .dragLeft, .dragDropped,
            .dragOfferChanged:
            nil
        }
    }
}
