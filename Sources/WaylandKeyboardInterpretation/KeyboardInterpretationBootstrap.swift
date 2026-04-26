import CXKBCommonSystem

public enum KeyboardInterpretationBootstrap {
    public static let ready = true

    public static func canCreateContext() -> Bool {
        guard let context = xkb_context_new(XKB_CONTEXT_NO_FLAGS) else {
            return false
        }

        xkb_context_unref(context)
        return true
    }
}
