import WaylandRaw

extension TextInputContentHints {
    package var rawTextInputContentHint: RawTextInputContentHint {
        RawTextInputContentHint(rawValue: rawValue)
    }
}

extension TextInputContentPurpose {
    package var rawTextInputContentPurpose: RawTextInputContentPurpose {
        RawTextInputContentPurpose(rawValue: rawValue)
    }
}

extension TextInputChangeCause {
    package var rawTextInputChangeCause: RawTextInputChangeCause {
        RawTextInputChangeCause(rawValue: rawValue)
    }
}

extension RawTextInputAction {
    package var textInputAction: TextInputAction {
        TextInputAction(rawValue: rawValue)
    }
}

extension RawTextInputPreeditHint {
    package var textInputPreeditHint: TextInputPreeditHint {
        TextInputPreeditHint(
            start: start,
            end: end,
            kind: TextInputPreeditHintKind(rawValue: hint)
        )
    }
}
