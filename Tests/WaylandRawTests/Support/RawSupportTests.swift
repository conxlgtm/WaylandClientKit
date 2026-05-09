import Glibc
import Testing

@testable import WaylandRaw

@Suite
struct RawSupportTests {
    @Test
    func rawGlobalAdvertisementNegotiatesMinimumVersion() throws {
        let global = try unsafe #require(
            RawGlobalAdvertisement(
                name: 7,
                interfaceName: "xdg_wm_base",
                advertisedVersion: 7
            )
        )
        #expect(global.negotiatedVersion(supportedByClient: 6) == 6)
    }
    @Test
    func rawGlobalAdvertisementKeepsAdvertisedVersionWhenClientSupportsMore() throws {
        let global = try unsafe #require(
            RawGlobalAdvertisement(
                name: 7,
                interfaceName: "xdg_wm_base",
                advertisedVersion: 4
            )
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
    func rawDisplayDefaultsToConnectionLifetimeOwnership() throws {
        let displayPointer = try unsafe #require(OpaquePointer(bitPattern: 0x10))
        let display = unsafe RawDisplay(
            opaquePointer: displayPointer,
            version: 1
        )
        #expect(display.metadata.ownership == .connectionLifetime)
        #expect(display.description == "wl_display id=? v1 ownership=connectionLifetime")
    }
    @Test
    func rawRegistryDescriptionShowsSuppliedMetadata() throws {
        let registryPointer = try unsafe #require(OpaquePointer(bitPattern: 0x20))
        let registry = unsafe RawRegistry(
            opaquePointer: registryPointer,
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
    @Test
    func rawPipeDescriptorsAreCloseOnExec() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
            Glibc.close(descriptors.writeEnd)
        }
        let readFlags = Glibc.fcntl(descriptors.readEnd, F_GETFD)
        let writeFlags = Glibc.fcntl(descriptors.writeEnd, F_GETFD)
        #expect(readFlags & FD_CLOEXEC == FD_CLOEXEC)
        #expect(writeFlags & FD_CLOEXEC == FD_CLOEXEC)
    }
}
