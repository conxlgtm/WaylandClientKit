import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct PublicAPIOwnershipBaselineTests {
    @Test
    func capturesOwnershipMarkersOmittedBySymbolGraphs() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-api-ownership-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("FixtureLease.swift")
        try """
        public struct CopyableFixture: Sendable { // ~Copyable
            private let marker = "} borrowing get"
        }

        public struct GenericConstraintFixture<Element>: Sendable
        where Element: ~Copyable {}

        public struct CommentConstraint<T>: Sendable/**/where T: ~Copyable {}

        // These braces and ownership words must not affect the baseline: } borrowing get
        public struct FixtureLease:
            ~ /* ownership { marker */ Copyable,
            Sendable
        {
            private let marker = "}"
        }

        public extension FixtureLease {
            var value: Int {
                borrowing get { 42 }
            }
        }
        """.write(to: source, atomically: true, encoding: .utf8)
        try """
        extension FixtureLease {
            public var consumedValue: Int {
                consuming get { 42 }
            }
        }
        """.write(
            to: root.appendingPathComponent("ConsumingGetter.swift"),
            atomically: true,
            encoding: .utf8
        )

        let report = try SourceOwnershipAPIBaseline().render(
            moduleSources: ["Fixture": root]
        )

        #expect(report.contains("Fixture.FixtureLease\t~Copyable"))
        #expect(report.contains("Fixture.FixtureLease.value\tborrowing get"))
        #expect(report.contains("Fixture.FixtureLease.consumedValue\tconsuming get"))
        #expect(!report.contains("Fixture.CopyableFixture\t~Copyable"))
        #expect(!report.contains("Fixture.GenericConstraintFixture\t~Copyable"))
        #expect(!report.contains("Fixture.CommentConstraint\t~Copyable"))
    }
}
