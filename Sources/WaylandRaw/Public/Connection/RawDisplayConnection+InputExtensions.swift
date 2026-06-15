import CWaylandProtocols

extension RawDisplayConnection {
    @safe
    package func bindPointerGesturesOneShot() throws -> RawPointerGestures? {
        preconditionIsOwnerThread()
        guard let global = optionalGlobal(named: "zwp_pointer_gestures_v1") else {
            return nil
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.zwpPointerGesturesV1
        )
        guard
            let gestures = unsafe swl_registry_bind_zwp_pointer_gestures_v1(
                registry.opaquePointer,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("zwp_pointer_gestures_v1")
        }

        return try RawPointerGestures(
            pointer: gestures,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }

    @safe
    package func bindKeyboardShortcutsInhibitManagerOneShot() throws
        -> RawKeyboardShortcutsInhibitManager?
    {
        preconditionIsOwnerThread()
        guard
            let global = optionalGlobal(
                named: "zwp_keyboard_shortcuts_inhibit_manager_v1"
            )
        else {
            return nil
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.zwpKeyboardShortcutsInhibitManagerV1
        )
        guard
            let manager = unsafe swl_registry_bind_zwp_keyboard_shortcuts_inhibit_manager_v1(
                registry.opaquePointer,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("zwp_keyboard_shortcuts_inhibit_manager_v1")
        }

        return try RawKeyboardShortcutsInhibitManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }
}
