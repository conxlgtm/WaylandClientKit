import WaylandGraphicsPreview

func borrowAcrossSubmit(_ renderLease: consuming WaylandGraphicsExternalBufferRenderLease)
    async throws
{
    let contract = Ref(renderLease.contract)
    try await renderLease.submit()
    print(contract.value.generation)
}
