import CGBMShims

package enum GBMDRMFormat {
    package static let xrgb8888 = swl_drm_format_xrgb8888()
    package static let argb8888 = swl_drm_format_argb8888()
}

package enum GBMDRMModifier {
    package static let linear = swl_drm_format_mod_linear()
    package static let invalid = swl_drm_format_mod_invalid()
}

package struct GBMBufferUseFlags: OptionSet, Sendable {
    package let rawValue: UInt32

    package init(rawValue flags: UInt32) {
        rawValue = flags
    }

    package static let scanout = GBMBufferUseFlags(rawValue: swl_gbm_bo_use_scanout())
    package static let rendering = GBMBufferUseFlags(rawValue: swl_gbm_bo_use_rendering())
    package static let write = GBMBufferUseFlags(rawValue: swl_gbm_bo_use_write())
    package static let linear = GBMBufferUseFlags(rawValue: swl_gbm_bo_use_linear())

    package static let windowRendering: GBMBufferUseFlags = [.rendering]
}
