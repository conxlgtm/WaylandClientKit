import WaylandClient

extension WaylandGraphicsWindowBackingStorage {
    package static func shouldRequestPresentationFeedback(
        configuration: WaylandGraphicsConfiguration,
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) -> Bool {
        switch configuration.presentationFeedbackPolicy {
        case .none:
            false
        case .requestWhenAvailable, .require:
            capabilities.presentationFeedback.isAvailable
        }
    }
}

func clearSoftwareFrame(
    _ frame: borrowing SoftwareFrame,
    color: UInt32
) {
    frame.withXRGB8888Rows { _, pixels in
        for index in 0..<pixels.count {
            unsafe pixels[unchecked: index] = color
        }
    }
}
