import WaylandGraphicsPreview

func borrowAcrossSubmit(_ frameLease: consuming WaylandGraphicsFrameLease) async throws {
    let contract = Ref(frameLease.contract)
    try await frameLease.submit(.clearColor(.black))
    print(contract.value.generation)
}
