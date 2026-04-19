import Testing

@testable import WaylandRaw

@Suite
struct RawSupportTests {
    @Test
    func rawGlobalAdvertisementNegotiatesMinimumVersion() {
        let global = RawGlobalAdvertisement(
            name: 7,
            interfaceName: "xdg_wm_base",
            advertisedVersion: 7
        )

        #expect(global.negotiatedVersion(supportedByClient: 6) == 6)
    }

    @Test
    func rawGlobalAdvertisementKeepsAdvertisedVersionWhenClientSupportsMore() {
        let global = RawGlobalAdvertisement(
            name: 7,
            interfaceName: "xdg_wm_base",
            advertisedVersion: 4
        )

        #expect(global.negotiatedVersion(supportedByClient: 6) == 4)
    }

    @Test
    func rawProxyMetadataDescriptionShowsInterfaceOwnershipAndVersion() {
        let metadata = RawProxyMetadata(
            interfaceName: "wl_registry",
            version: 1,
            ownership: .borrowed,
            objectID: 4
        )

        #expect(metadata.description == "wl_registry id=4 v1 ownership=borrowed")
    }

    @Test
    func rawDisplayDefaultsToConnectionLifetimeOwnership() {
        let display = RawDisplay(
            opaquePointer: OpaquePointer(bitPattern: 0x10)!,
            version: 1
        )

        #expect(display.metadata.ownership == .connectionLifetime)
        #expect(display.description == "wl_display id=? v1 ownership=connectionLifetime")
    }

    @Test
    func rawRegistryDescriptionShowsSuppliedMetadata() {
        let registry = RawRegistry(
            opaquePointer: OpaquePointer(bitPattern: 0x20)!,
            version: 1,
            ownership: .borrowed,
            objectID: 2
        )

        #expect(registry.description == "wl_registry id=2 v1 ownership=borrowed")
    }

    @Test
    func rawVersionSupportsLiteralAndComparison() {
        let older: RawVersion = 1
        let newer: RawVersion = 3

        #expect(older < newer)
        #expect(newer > older)
        #expect(newer == 3)
    }

    @Test
    func rawObjectIDSupportsIntegerLiteral() {
        let objectID: RawObjectID = 9

        #expect(objectID.value == 9)
        #expect(objectID.description == "id=9")
    }
}
