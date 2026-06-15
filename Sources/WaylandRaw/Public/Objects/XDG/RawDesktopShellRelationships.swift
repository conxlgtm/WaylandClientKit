import CWaylandProtocols

@safe
package final class RawXDGDialogManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "xdg_wm_dialog_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_xdg_wm_dialog_v1_destroy
        )
    }

    package func createDialog(for topLevel: RawXDGTopLevel) throws -> RawXDGDialog {
        guard
            let dialogPointer = unsafe swl_xdg_wm_dialog_v1_get_xdg_dialog(
                pointer,
                topLevel.pointer
            )
        else {
            throw RuntimeError.bindFailed("xdg_dialog_v1")
        }

        let adoptedDialogPointer = try unsafe proxyAdoption.adoptOrDestroy(
            dialogPointer,
            interface: "xdg_dialog_v1",
            destroy: unsafe swl_xdg_dialog_v1_destroy
        )
        return RawXDGDialog(pointer: adoptedDialogPointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawXDGDialog {
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(pointer dialogPointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: dialogPointer,
            destroy: unsafe swl_xdg_dialog_v1_destroy
        )
    }

    package func setModal() {
        unsafe swl_xdg_dialog_v1_set_modal(pointer)
    }

    package func unsetModal() {
        unsafe swl_xdg_dialog_v1_unset_modal(pointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawXDGToplevelDragManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "xdg_toplevel_drag_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_xdg_toplevel_drag_manager_v1_destroy
        )
    }

    package func createToplevelDrag(source: RawDataSource) throws -> RawXDGToplevelDrag {
        guard
            let dragPointer = unsafe swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag(
                pointer,
                source.pointer
            )
        else {
            throw RuntimeError.bindFailed("xdg_toplevel_drag_v1")
        }

        let adoptedDragPointer = try unsafe proxyAdoption.adoptOrDestroy(
            dragPointer,
            interface: "xdg_toplevel_drag_v1",
            destroy: unsafe swl_xdg_toplevel_drag_v1_destroy
        )
        return RawXDGToplevelDrag(pointer: adoptedDragPointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawXDGToplevelDrag {
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(pointer dragPointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: dragPointer,
            destroy: unsafe swl_xdg_toplevel_drag_v1_destroy
        )
    }

    package func attach(topLevel: RawXDGTopLevel, xOffset: Int32, yOffset: Int32) {
        unsafe swl_xdg_toplevel_drag_v1_attach(
            pointer,
            topLevel.pointer,
            xOffset,
            yOffset
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawForeignToplevelList {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer listPointer: OpaquePointer,
        version listVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = listVersion
        proxy = try RawOwnedProxy(
            adopting: listPointer,
            interface: "ext_foreign_toplevel_list_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_ext_foreign_toplevel_list_v1_destroy
        )
    }

    package func stop() {
        unsafe swl_ext_foreign_toplevel_list_v1_stop(pointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawForeignToplevelHandle {
    private var proxy: RawOwnedProxy

    @safe
    init(pointer handlePointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: handlePointer,
            destroy: unsafe swl_ext_foreign_toplevel_handle_v1_destroy
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
