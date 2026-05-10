import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowOutputMembershipStateTests {
    @Test
    func enterRecordsSortedOutputIDs() {
        var state = WindowOutputMembershipState()

        let enteredThirdOutput = state.enter(RawOutputID(rawValue: 3))
        let enteredFirstOutput = state.enter(RawOutputID(rawValue: 1))

        #expect(enteredThirdOutput)
        #expect(enteredFirstOutput)
        #expect(
            state.currentOutputIDs()
                == [OutputID(rawValue: 1), OutputID(rawValue: 3)]
        )
    }

    @Test
    func duplicateEnterAndUnknownLeaveDoNotReportChange() {
        var state = WindowOutputMembershipState()

        let enteredOutput = state.enter(RawOutputID(rawValue: 2))
        let duplicateEnter = state.enter(RawOutputID(rawValue: 2))
        let unknownLeave = state.leave(RawOutputID(rawValue: 9))

        #expect(enteredOutput)
        #expect(!duplicateEnter)
        #expect(!unknownLeave)
        #expect(state.currentOutputIDs() == [OutputID(rawValue: 2)])
    }

    @Test
    func leaveDropsOnlyMatchingOutput() {
        var state = WindowOutputMembershipState()
        _ = state.enter(RawOutputID(rawValue: 1))
        _ = state.enter(RawOutputID(rawValue: 2))

        let leftOutput = state.leave(RawOutputID(rawValue: 1))

        #expect(leftOutput)
        #expect(state.currentOutputIDs() == [OutputID(rawValue: 2)])
    }

    @Test
    func removeDropsOutputByPublicID() {
        var state = WindowOutputMembershipState()
        _ = state.enter(RawOutputID(rawValue: 1))
        _ = state.enter(RawOutputID(rawValue: 4))

        let removedOutput = state.remove(OutputID(rawValue: 4))

        #expect(removedOutput)
        #expect(state.currentOutputIDs() == [OutputID(rawValue: 1)])
    }

    @Test
    func currentOutputIDsFiltersUnboundOutputs() {
        var state = WindowOutputMembershipState()
        _ = state.enter(RawOutputID(rawValue: 1))
        _ = state.enter(RawOutputID(rawValue: 2))

        let outputIDs = state.currentOutputIDs { $0.rawValue != 1 }

        #expect(outputIDs == [OutputID(rawValue: 2)])
    }
}
