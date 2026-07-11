import Foundation
import Testing
import WaylandExampleSupport

struct ExampleStateRootResolverTests {
    @Test
    func absoluteExplicitRootWinsOverEnvironment() throws {
        let resolver = ExampleStateRootResolver(
            appID: "org.example.App",
            explicitRoot: "/tmp/example-state",
            environment: [
                "XDG_STATE_HOME": "/tmp/xdg-state",
                "HOME": "/home/example",
            ]
        )

        #expect(
            try resolver.stateFile().path
                == "/tmp/example-state/org.example.App/session.json")
    }

    @Test
    func relativeExplicitRootIsRejected() throws {
        let resolver = ExampleStateRootResolver(
            appID: "org.example.App",
            explicitRoot: "relative-state",
            environment: ["HOME": "/home/example"]
        )

        #expect(
            throws: ExampleStateRootError.relativeStateRoot(
                argument: "--state-root",
                path: "relative-state"
            )
        ) {
            try resolver.stateRootURL()
        }
    }

    @Test
    func absoluteXDGStateHomeIsUsed() throws {
        let resolver = ExampleStateRootResolver(
            appID: "org.example.App",
            environment: [
                "XDG_STATE_HOME": "/tmp/xdg-state",
                "HOME": "/home/example",
            ]
        )

        #expect(try resolver.stateRootURL().path == "/tmp/xdg-state")
    }

    @Test
    func relativeXDGStateHomeIsIgnored() throws {
        let resolver = ExampleStateRootResolver(
            appID: "org.example.App",
            environment: [
                "XDG_STATE_HOME": "relative-state",
                "HOME": "/home/example",
            ]
        )

        #expect(try resolver.stateRootURL().path == "/home/example/.local/state")
    }

    @Test
    func missingAbsoluteStateRootThrows() throws {
        let resolver = ExampleStateRootResolver(
            appID: "org.example.App",
            environment: [
                "XDG_STATE_HOME": "relative-state",
                "HOME": "relative-home",
            ]
        )

        #expect(throws: ExampleStateRootError.missingStateRoot) {
            try resolver.stateRootURL()
        }
    }
}
