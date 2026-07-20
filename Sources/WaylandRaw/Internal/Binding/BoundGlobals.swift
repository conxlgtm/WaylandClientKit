import CWaylandClientSystem
import CWaylandProtocols

extension OptionalGlobals {
    package var supportsFractionalScaling: Bool {
        switch (viewporter, fractionalScaleManager) {
        case (.bound, .bound):
            true
        case (.missing, _),
            (_, .missing):
            false
        }
    }
}

package final class BoundGlobals {
    package let compositor: RawCompositor
    package let sharedMemory: RawSharedMemory
    package let xdgWMBase: RawXDGWMBase
    package let extensions: OptionalGlobals
    package let seatRegistry: SeatRegistry
    package private(set) var tabletSeatRegistry: TabletSeatRegistry?
    package let outputRegistry: OutputRegistry

    private var isDestroyed = false

    init(
        compositor boundCompositor: RawCompositor,
        sharedMemory boundSharedMemory: RawSharedMemory,
        xdgWMBase boundXDGWMBase: RawXDGWMBase,
        seatRegistry boundSeatRegistry: SeatRegistry,
        outputRegistry boundOutputRegistry: OutputRegistry,
        extensions boundExtensions: OptionalGlobals = OptionalGlobals(),
        tabletSeatRegistry boundTabletSeatRegistry: TabletSeatRegistry? = nil
    ) {
        compositor = boundCompositor
        sharedMemory = boundSharedMemory
        xdgWMBase = boundXDGWMBase
        seatRegistry = boundSeatRegistry
        tabletSeatRegistry = boundTabletSeatRegistry
        outputRegistry = boundOutputRegistry
        extensions = boundExtensions
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        outputRegistry.destroy()
        tabletSeatRegistry?.destroy()
        seatRegistry.destroy()
        extensions.destroy()
        xdgWMBase.destroy()
        sharedMemory.destroy()
        compositor.destroy()
    }

    package func invalidateOptionalGlobal(named interfaceName: String) {
        if interfaceName == "zxdg_output_manager_v1" {
            outputRegistry.invalidateXDGOutputManager()
        }
        if interfaceName == "zwp_tablet_manager_v2" {
            tabletSeatRegistry?.destroy()
            tabletSeatRegistry = nil
        }
        extensions.invalidate(named: interfaceName)
    }

    deinit {
        destroy()
    }
}
