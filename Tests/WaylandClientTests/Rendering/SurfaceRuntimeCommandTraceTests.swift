import Testing
import WaylandRaw

@testable import WaylandClient

@Suite(.timeLimit(.minutes(1)))
struct SurfaceRuntimeCommandTraceTests {
    @Test
    func generatedCommandsPreserveLifecycleRules() {
        for seed in 1...100 {
            var trace = SurfaceRuntimeCommandTrace(seed: UInt64(seed))
            for _ in 0..<100 {
                trace.runNextCommand()
            }
        }
    }
}

private struct SurfaceRuntimeCommandTrace {
    private struct RoleToken: Equatable {
        let rawValue: Int
    }

    private enum RolePhase {
        case unassigned
        case live(RoleToken)
        case destroyed
    }

    private var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
    private var rolePhase = RolePhase.unassigned
    private var isSurfaceDestroyed = false
    private var outputIDs: Set<UInt32> = []
    private var presentationFeedback = SurfaceCapabilityStatus.unavailable
    private var nextRoleToken = 1
    private var random: SurfaceRuntimeTraceRandom

    init(seed: UInt64) {
        random = SurfaceRuntimeTraceRandom(seed: seed)
    }

    mutating func runNextCommand() {
        switch random.next() % 7 {
        case 0:
            installRoleResources()
        case 1:
            removeRoleResources()
        case 2:
            enterOutput()
        case 3:
            leaveOutput()
        case 4:
            removeOutput()
        case 5:
            destroySurface()
        default:
            setPresentationFeedbackCapability()
        }
        expectRuntimeMatchesModel()
    }

    private mutating func installRoleResources() {
        let token = RoleToken(rawValue: nextRoleToken)
        nextRoleToken += 1
        let expectedError: SurfaceRuntimeError? =
            if isSurfaceDestroyed {
                .installAfterSurfaceDestroyed
            } else {
                switch rolePhase {
                case .unassigned:
                    nil
                case .live:
                    .roleResourcesAlreadyInstalled(role: .toplevelWindow)
                case .destroyed:
                    .installAfterRoleDestroyed(role: .toplevelWindow)
                }
            }

        let actualError: SurfaceRuntimeError?
        do {
            try runtime.installRoleResources(token)
            actualError = nil
        } catch let error as SurfaceRuntimeError {
            actualError = error
        } catch {
            Issue.record("unexpected role installation error: \(error)")
            return
        }

        #expect(actualError == expectedError)
        if expectedError == nil {
            rolePhase = .live(token)
        }
    }

    private mutating func removeRoleResources() {
        let expected: RoleToken?
        switch rolePhase {
        case .live(let token) where !isSurfaceDestroyed:
            expected = token
            rolePhase = .destroyed
        case .unassigned, .live, .destroyed:
            expected = nil
        }
        #expect(runtime.removeRoleResources() == expected)
    }

    private mutating func enterOutput() {
        let rawValue = nextOutputRawValue()
        let expected = !isSurfaceDestroyed && outputIDs.insert(rawValue).inserted
        #expect(runtime.enterOutput(RawOutputID(rawValue: rawValue)) == expected)
    }

    private mutating func leaveOutput() {
        let rawValue = nextOutputRawValue()
        let expected = !isSurfaceDestroyed && outputIDs.remove(rawValue) != nil
        #expect(runtime.leaveOutput(RawOutputID(rawValue: rawValue)) == expected)
    }

    private mutating func removeOutput() {
        let rawValue = nextOutputRawValue()
        let expected = !isSurfaceDestroyed && outputIDs.remove(rawValue) != nil
        #expect(runtime.removeOutput(OutputID(rawValue: rawValue)) == expected)
    }

    private mutating func destroySurface() {
        let expectedError: SurfaceRuntimeError? =
            if case .live = rolePhase {
                .surfaceDestroyedWithLiveRoleResources
            } else {
                nil
            }
        let actualError: SurfaceRuntimeError?
        do {
            try runtime.markSurfaceDestroyed()
            actualError = nil
        } catch let error as SurfaceRuntimeError {
            actualError = error
        } catch {
            Issue.record("unexpected surface destruction error: \(error)")
            return
        }

        #expect(actualError == expectedError)
        if expectedError == nil {
            isSurfaceDestroyed = true
            outputIDs.removeAll()
            presentationFeedback = .unavailable
        }
    }

    private mutating func setPresentationFeedbackCapability() {
        let capability: SurfaceCapabilityStatus =
            random.next().isMultiple(of: 2) ? .available : .unavailable
        runtime.setPresentationFeedbackCapability(capability)
        if !isSurfaceDestroyed {
            presentationFeedback = capability
        }
    }

    private mutating func nextOutputRawValue() -> UInt32 {
        UInt32(random.next() % 4 + 1)
    }

    private func expectRuntimeMatchesModel() {
        let expectedRoleResources: RoleToken? =
            if case .live(let token) = rolePhase, !isSurfaceDestroyed {
                token
            } else {
                nil
            }
        #expect(runtime.roleResources == expectedRoleResources)
        #expect(runtime.currentOutputIDs().map(\.rawValue) == outputIDs.sorted())
        #expect(runtime.capabilitySnapshot().presentationFeedback == presentationFeedback)
        #expect(runtime.roleReadinessSnapshot.hasRuntime == !isSurfaceDestroyed)
        #expect(runtime.roleReadinessSnapshot.hasRoleResources == (expectedRoleResources != nil))
    }
}

private struct SurfaceRuntimeTraceRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
