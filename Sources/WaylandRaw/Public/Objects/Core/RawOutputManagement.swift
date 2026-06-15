import CWaylandProtocols

@safe
package final class RawWlrOutputManager {
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
            interface: "zwlr_output_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwlr_output_manager_v1_destroy
        )
    }

    package func createConfiguration(serial: UInt32) throws -> RawWlrOutputConfiguration {
        guard
            let configuration = unsafe swl_zwlr_output_manager_v1_create_configuration(
                pointer,
                serial
            )
        else {
            throw RuntimeError.bindFailed("zwlr_output_configuration_v1")
        }

        let adoptedConfiguration = try unsafe proxyAdoption.adoptOrDestroy(
            configuration,
            interface: "zwlr_output_configuration_v1",
            destroy: unsafe swl_zwlr_output_configuration_v1_destroy
        )
        return RawWlrOutputConfiguration(pointer: adoptedConfiguration)
    }

    package func stop() {
        unsafe swl_zwlr_output_manager_v1_stop(pointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawWlrOutputHead {
    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(pointer headPointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: headPointer,
            destroy: unsafe swl_zwlr_output_head_v1_destroy
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
package final class RawWlrOutputMode {
    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(pointer modePointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: modePointer,
            destroy: unsafe swl_zwlr_output_mode_v1_destroy
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
package final class RawWlrOutputConfiguration {
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(pointer configurationPointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: configurationPointer,
            destroy: unsafe swl_zwlr_output_configuration_v1_destroy
        )
    }

    package func enable(head: RawWlrOutputHead) throws -> RawWlrOutputConfigurationHead {
        guard
            let configurationHead = unsafe swl_zwlr_output_configuration_v1_enable_head(
                pointer,
                head.pointer
            )
        else {
            throw RuntimeError.bindFailed("zwlr_output_configuration_head_v1")
        }

        return RawWlrOutputConfigurationHead(pointer: configurationHead)
    }

    package func disable(head: RawWlrOutputHead) {
        unsafe swl_zwlr_output_configuration_v1_disable_head(pointer, head.pointer)
    }

    package func test() {
        unsafe swl_zwlr_output_configuration_v1_test(pointer)
    }

    package func apply() {
        unsafe swl_zwlr_output_configuration_v1_apply(pointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawWlrOutputConfigurationHead {
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(pointer headPointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: headPointer,
            destroy: unsafe swl_zwlr_output_configuration_head_v1_destroy
        )
    }

    package func setMode(_ mode: RawWlrOutputMode) {
        unsafe swl_zwlr_output_configuration_head_v1_set_mode(pointer, mode.pointer)
    }

    package func setCustomMode(width: Int32, height: Int32, refresh: Int32) {
        unsafe swl_zwlr_output_configuration_head_v1_set_custom_mode(
            pointer,
            width,
            height,
            refresh
        )
    }

    package func setPosition(x: Int32, y: Int32) {
        unsafe swl_zwlr_output_configuration_head_v1_set_position(pointer, x, y)
    }

    package func setTransform(_ transform: Int32) {
        unsafe swl_zwlr_output_configuration_head_v1_set_transform(pointer, transform)
    }

    package func setScale(_ scale: WaylandFixed) {
        unsafe swl_zwlr_output_configuration_head_v1_set_scale(pointer, scale.rawValue)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
