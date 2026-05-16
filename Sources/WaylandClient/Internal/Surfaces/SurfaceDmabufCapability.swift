import WaylandRaw

extension OptionalLinuxDmabuf {
    var surfaceDmabufAdvertisement: SurfaceDmabufAdvertisement {
        switch self {
        case .missing:
            .unavailable
        case .bound(let linuxDmabuf):
            .advertised(
                version: linuxDmabuf.version,
                canRequestSurfaceFeedback: linuxDmabuf.version
                    >= RawLinuxDmabuf.feedbackRequestMinimumVersion
                    ? .available
                    : .unavailable
            )
        }
    }
}

package enum SurfaceDmabufCapabilityError: Error, Equatable, Sendable {
    case missingSurfaceIdentity
    case defaultFeedbackForSurface
    case mismatchedSurfaceFeedback(expected: RawObjectID, actual: RawObjectID)
}

package struct SurfaceDmabufFeedback: Equatable, Sendable {
    package let surfaceID: RawObjectID
    package let snapshot: RawLinuxDmabufFeedbackSnapshot

    package init(
        snapshot feedbackSnapshot: RawLinuxDmabufFeedbackSnapshot,
        surfaceID expectedSurfaceID: RawObjectID
    ) throws(SurfaceDmabufCapabilityError) {
        guard case .surface(let actualSurfaceID) = feedbackSnapshot.scope else {
            throw SurfaceDmabufCapabilityError.defaultFeedbackForSurface
        }
        guard actualSurfaceID == expectedSurfaceID else {
            throw SurfaceDmabufCapabilityError.mismatchedSurfaceFeedback(
                expected: expectedSurfaceID,
                actual: actualSurfaceID
            )
        }

        surfaceID = expectedSurfaceID
        snapshot = feedbackSnapshot
    }
}

package enum SurfaceDmabufAdvertisement: Equatable, Sendable {
    case unavailable
    case advertised(version: RawVersion, canRequestSurfaceFeedback: SurfaceCapabilityStatus)
}

package enum SurfaceDmabufCapability: Equatable, Sendable {
    case unavailable
    case advertised(version: RawVersion, canRequestSurfaceFeedback: SurfaceCapabilityStatus)
    case surfaceFeedback(SurfaceDmabufFeedback)
}
