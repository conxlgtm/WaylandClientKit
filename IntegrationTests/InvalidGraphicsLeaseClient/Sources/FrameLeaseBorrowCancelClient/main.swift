import WaylandGraphicsPreview

func borrowAcrossCancel(_ frameLease: consuming WaylandGraphicsFrameLease) async {
    let contract = Ref(frameLease.contract)
    await frameLease.cancel()
    print(contract.value.generation)
}
