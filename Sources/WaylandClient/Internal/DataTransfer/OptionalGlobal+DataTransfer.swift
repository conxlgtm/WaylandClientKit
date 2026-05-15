import WaylandRaw

extension OptionalGlobal where Bound == RawDataDeviceManager {
    package var dataTransferBindingState: DataTransferGlobalBindingState {
        isBound ? .boundWithDataDeviceManager : .boundWithoutDataDeviceManager
    }
}

extension OptionalGlobal where Bound == RawPrimarySelectionDeviceManager {
    package var primarySelectionBindingState: PrimarySelectionGlobalBindingState {
        isBound ? .boundWithPrimaryManager : .boundWithoutPrimaryManager
    }
}
