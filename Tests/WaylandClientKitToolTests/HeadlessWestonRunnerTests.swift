import Foundation
import Synchronization
import Testing
import WaylandClientKitToolSupport

@Suite
struct HeadlessWestonRunnerTests {
    @Test(arguments: ["never", "nonsocket", "early"])
    func readinessFailuresSettleWestonAndRemovePrivateRuntime(_ mode: String) async throws {
        let fixture = try HeadlessBehaviorFixture(westonMode: mode)
        defer { fixture.process.remove() }
        do {
            try await fixture.run()
            Issue.record("expected readiness failure")
        } catch let error as ToolError {
            #expect(error.exitCode == ToolExitCode.process)
            #expect(
                error.message.contains(
                    mode == "early" ? "exited before creating" : "did not create"))
        }
        let events = try fixture.events()
        #expect(events.contains("permissions=0o700"))
        #expect(!events.contains("child-started"))
        try fixture.assertRemovedAndReaped(events)
        if mode == "early" {
            #expect(fixture.messages.withLock { $0.joined().contains("early weston diagnostic") })
        } else {
            #expect(events.contains("runtime-at-weston-stop=1"))
            #expect(fixture.messages.withLock { $0.joined().contains("late weston diagnostic") })
        }
    }

    @Test
    func successPreservesChildCwdEnvironmentAndWaitsForWeston() async throws {
        let fixture = try HeadlessBehaviorFixture()
        defer { fixture.process.remove() }
        try await fixture.run()
        let events = try fixture.events()
        #expect(events.contains("child-cwd=\(fixture.process.root.path)"))
        #expect(events.contains("child-wayland-socket=False"))
        #expect(events.contains("weston-stop child-alive=0"))
        #expect(events.contains("runtime-at-weston-stop=1"))
        try fixture.assertRemovedAndReaped(events)
    }

    @Test
    func failureRetainsBothStreamsAndLateWestonDiagnostics() async throws {
        let fixture = try HeadlessBehaviorFixture(childMode: "failure")
        defer { fixture.process.remove() }
        do {
            try await fixture.run()
            Issue.record("expected child failure")
        } catch let error as ToolError {
            #expect(error.exitCode == 7)
            #expect(error.message.contains("headless command failed with exit code 7"))
        }
        let messages = fixture.messages.withLock { $0.joined(separator: "\n") }
        #expect(messages.contains("child stdout diagnostic"))
        #expect(messages.contains("child stderr diagnostic"))
        #expect(messages.contains("late weston diagnostic"))
        try fixture.assertRemovedAndReaped(fixture.events())
    }

    @Test
    func deadlineAllowsGraceAndSettlesChildBeforeWeston() async throws {
        let fixture = try HeadlessBehaviorFixture(childMode: "delayed")
        defer { fixture.process.remove() }
        let start = ContinuousClock.now
        do {
            try await fixture.run(timeout: 0.3)
            Issue.record("expected child deadline")
        } catch let error as ToolError {
            #expect(error.message.contains("headless command timed out"))
        }
        #expect(start.duration(to: .now) >= .milliseconds(500))
        let events = try fixture.events()
        try assertOrderedTeardown(events)
        #expect(fixture.messages.withLock { $0.joined().contains("late child diagnostic") })
        try fixture.assertRemovedAndReaped(events)
    }

    @Test
    func resistantChildAndWestonReceiveFiveSecondGraceThenAreReaped() async throws {
        let fixture = try HeadlessBehaviorFixture(westonMode: "resistant", childMode: "resistant")
        defer { fixture.process.remove() }
        let start = ContinuousClock.now
        do {
            try await fixture.run(timeout: 0.3)
            Issue.record("expected resistant child deadline")
        } catch let error as ToolError {
            #expect(error.exitCode == 9)
            #expect(error.message.contains("timed out"))
        }
        #expect(start.duration(to: .now) >= .seconds(10))
        let events = try fixture.events()
        try assertOrderedTeardown(events)
        #expect(fixture.messages.withLock { $0.joined().contains("late child diagnostic") })
        #expect(fixture.messages.withLock { $0.joined().contains("late weston diagnostic") })
        try fixture.assertRemovedAndReaped(events)
    }

    @Test(arguments: ["startup", "child", "child-grace", "weston-grace"])
    func cancellationAtEachStageMaintainsTeardownOrder(_ stage: String) async throws {
        let fixture = try HeadlessBehaviorFixture(
            westonMode: stage == "startup"
                ? "never" : stage == "weston-grace" ? "resistant" : "ready",
            childMode: stage == "weston-grace" ? "success" : "delayed")
        defer { fixture.process.remove() }
        // swiftlint:disable:next no_unstructured_task
        let task = Task { @concurrent in
            try await fixture.run(timeout: stage == "child-grace" ? 0.2 : 60)
        }
        defer {
            task.cancel()
            _ = await task.result
        }
        let marker: String
        switch stage {
        case "startup": marker = "weston-started"
        case "child": marker = "child-started"
        case "child-grace": marker = "child-stop"
        default: marker = "weston-stop"
        }
        try await fixture.process.waitForFile(fixture.eventsURL, containing: marker)
        task.cancel()
        do {
            try await task.value
            Issue.record("expected supervisor cancellation")
        } catch is CancellationError {
            // Cancellation is reported after both owned executions settle.
        } catch let error as ToolError {
            #expect(stage == "child-grace" && error.message.contains("timed out"))
        }
        let events = try fixture.events()
        if stage == "child" || stage == "child-grace" { try assertOrderedTeardown(events) }
        #expect(events.contains("weston-stop child-alive=0"))
        try fixture.assertRemovedAndReaped(events)
    }

    @Test
    func childLookupFailureStillSettlesWestonAndRemovesRuntime() async throws {
        let fixture = try HeadlessBehaviorFixture()
        defer { fixture.process.remove() }
        do {
            try await fixture.run(command: ["missing-child"])
            Issue.record("expected child lookup failure")
        } catch let error as ToolError {
            #expect(error.exitCode == ToolExitCode.environment)
            #expect(error.message.contains("executable not found on PATH: missing-child"))
        }
        let events = try fixture.events()
        #expect(!events.contains("child-started"))
        #expect(events.contains("weston-stop child-alive=0"))
        #expect(fixture.messages.withLock { $0.joined().contains("late weston diagnostic") })
        try fixture.assertRemovedAndReaped(events)
    }

    @Test
    func wckCommandUsesSelectedSwiftExecutable() async throws {
        let fixture = try HeadlessBehaviorFixture()
        defer { fixture.process.remove() }
        _ = try fixture.process.install("swift")
        try await fixture.run(command: ["wck", "check", "cheap"])
        #expect(
            try fixture.events().contains("child-args=[\"run\", \"wck\", \"check\", \"cheap\"]"))
    }

    private func assertOrderedTeardown(_ events: String) throws {
        let child = try #require(events.range(of: "child-stop"))
        let weston = try #require(events.range(of: "weston-stop"))
        #expect(child.lowerBound < weston.lowerBound)
        #expect(events.contains("weston-stop child-alive=0"))
        #expect(events.contains("runtime-at-child-stop=1"))
        #expect(events.contains("runtime-at-weston-stop=1"))
    }
}

private final class HeadlessBehaviorFixture: Sendable {
    let process: ProcessBehaviorFixture
    let environment: [String: String]
    let eventsURL: URL
    let messages = Mutex<[String]>([])

    init(westonMode: String = "ready", childMode: String = "success") throws {
        let process = try ProcessBehaviorFixture()
        _ = try process.install("weston")
        _ = try process.install("child")
        let eventsURL = process.root.appendingPathComponent("events")
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = process.root.path
        environment["SWIFT_BIN"] = process.root.appendingPathComponent("swift").path
        environment["WCK_EVENTS"] = eventsURL.path
        environment["WCK_WESTON_MODE"] = westonMode
        environment["WCK_CHILD_MODE"] = childMode
        environment["WAYLAND_SOCKET"] = "must-be-removed"
        self.environment = environment
        self.process = process
        self.eventsURL = eventsURL
    }

    func run(timeout: TimeInterval = 30, command: [String] = ["child"]) async throws {
        let errorOutput: @Sendable (String) -> Void = { text in
            self.messages.withLock { $0.append(text) }
        }
        let diagnostics = Diagnostics(errorOutput: errorOutput)
        let context = ToolContext(
            repository: Repository(root: process.root), diagnostics: diagnostics,
            runner: ProcessRunner(environment: environment, diagnostics: diagnostics))
        try await HeadlessWestonRunner(context: context).run(
            command: command, timeoutSeconds: timeout)
    }

    func events() throws -> String {
        try String(contentsOf: eventsURL, encoding: .utf8)
    }

    func assertRemovedAndReaped(_ events: String) throws {
        let runtimeLine = try #require(
            events.split(separator: "\n").first { $0.hasPrefix("runtime=") })
        let runtime = String(runtimeLine.dropFirst("runtime=".count))
        #expect(!FileManager.default.fileExists(atPath: runtime))
        for prefix in ["weston-pid=", "child-pid="] {
            if let line = events.split(separator: "\n").first(where: { $0.hasPrefix(prefix) }),
                let pid = Int32(line.dropFirst(prefix.count))
            {
                process.assertReaped(pid)
            }
        }
    }
}
