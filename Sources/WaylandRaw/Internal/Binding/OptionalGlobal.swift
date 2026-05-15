package protocol RawDestroyableObject: AnyObject {
    func destroy()
}

package enum OptionalGlobal<Bound: RawDestroyableObject> {
    case missing
    case bound(Bound)

    package var boundObject: Bound? {
        guard case .bound(let object) = self else { return nil }

        return object
    }

    package func destroy() {
        boundObject?.destroy()
    }
}

package enum OptionalVersionedGlobal<Bound: RawDestroyableObject> {
    case missing
    case unsupportedVersion(advertised: RawVersion, minimum: RawVersion)
    case bound(Bound)

    package var boundObject: Bound? {
        guard case .bound(let object) = self else { return nil }

        return object
    }

    package func destroy() {
        boundObject?.destroy()
    }
}

extension RawXDGDecorationManager: RawDestroyableObject {}
extension RawXDGOutputManager: RawDestroyableObject {}
extension RawViewporter: RawDestroyableObject {}
extension RawPresentation: RawDestroyableObject {}
extension RawFractionalScaleManager: RawDestroyableObject {}
extension RawDataDeviceManager: RawDestroyableObject {}
extension RawPrimarySelectionDeviceManager: RawDestroyableObject {}
extension RawLinuxDmabuf: RawDestroyableObject {}

package typealias OptionalXDGDecorationManager = OptionalVersionedGlobal<RawXDGDecorationManager>
package typealias OptionalXDGOutputManager = OptionalVersionedGlobal<RawXDGOutputManager>
package typealias OptionalViewporter = OptionalGlobal<RawViewporter>
package typealias OptionalPresentation = OptionalGlobal<RawPresentation>
package typealias OptionalFractionalScaleManager = OptionalGlobal<RawFractionalScaleManager>
package typealias OptionalDataDeviceManager = OptionalGlobal<RawDataDeviceManager>
package typealias OptionalPrimarySelectionDeviceManager =
    OptionalGlobal<RawPrimarySelectionDeviceManager>
package typealias OptionalLinuxDmabuf = OptionalGlobal<RawLinuxDmabuf>
