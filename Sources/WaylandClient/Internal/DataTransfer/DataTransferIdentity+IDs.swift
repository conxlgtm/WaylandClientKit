extension DataOfferID {
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
