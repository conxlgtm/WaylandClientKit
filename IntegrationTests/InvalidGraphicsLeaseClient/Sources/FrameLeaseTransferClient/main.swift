import WaylandGraphicsPreview

func useTransferredFrameLease(
    _ frameLease: consuming WaylandGraphicsFrameLease,
    buffer: WaylandGraphicsExternalBuffer
) async throws {
    let renderLease = try await frameLease.reserveExternalBuffer(buffer)
    await frameLease.cancel()
    await renderLease.cancel()
}
