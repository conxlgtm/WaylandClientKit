import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct PublicAPIOwnershipBaselineTests {
    @Test
    func capturesOwnershipMarkersOmittedBySymbolGraphs() throws {
        let records = try ownershipRecords(sources: [
            "FixtureLease.swift": """
            public struct CopyableFixture: Sendable { // ~Copyable
                private let marker = "} borrowing get borrow mutate"
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
            """,
            "ConsumingGetter.swift": """
            extension FixtureLease {
                public var consumedValue: Int {
                    consuming get { 42 }
                }
            }
            """,
        ])

        #expect(
            records == [
                "Fixture.FixtureLease\t~Copyable",
                "Fixture.FixtureLease.value\tborrowing get",
                "Fixture.FixtureLease.consumedValue\tconsuming get",
            ])
    }

    @Test
    func capturesBothAccessorsInBorrowOnlyFiles() throws {
        let records = try ownershipRecords(sources: [
            "BorrowView.swift": """
            public struct BorrowView {
                private var stored: Int
                public var value: Int {
                    borrow { stored }
                    mutate { &stored }
                }
            }
            """
        ])

        #expect(
            records == [
                "Fixture.BorrowView.value\tborrow",
                "Fixture.BorrowView.value\tmutate",
            ])
    }

    @Test
    func capturesOwnershipGettersInCopyableTypesAndPublicExtensions() throws {
        let records = try ownershipRecords(sources: [
            "CopyableViews.swift": """
            public struct CopyableView {
                public var value: Int { borrowing get { 42 } }
                public struct Nested {
                    public var value: Int { consuming get { 42 } }
                }
            }
            public enum CopyableChoice {
                case value
                public var number: Int { borrowing get { 42 } }
            }
            """,
            "Extensions.swift": """
            public extension CopyableView {
                var borrowed: Int { borrow { 42 } }
                var consumed: Int { consuming get { 42 } }
            }
            extension CopyableView.Nested {
                public var borrowed: Int { borrow { 42 } }
            }
            """,
        ])

        #expect(
            records == [
                "Fixture.CopyableView.value\tborrowing get",
                "Fixture.CopyableView.Nested.value\tconsuming get",
                "Fixture.CopyableChoice.number\tborrowing get",
                "Fixture.CopyableView.borrowed\tborrow",
                "Fixture.CopyableView.consumed\tconsuming get",
                "Fixture.CopyableView.Nested.borrowed\tborrow",
            ])
    }

    @Test
    func omitsHiddenTypesAndExplicitlyHiddenExtensionMembers() throws {
        let records = try ownershipRecords(sources: [
            // This file deliberately has no ownership markers; it still determines
            // whether extension properties in another file are externally public.
            "Declarations.swift": """
            public struct Visible {
                public struct Nested {}
                private struct HiddenNested {}
                struct InternalNested {}
            }
            private struct Hidden {
                public struct Nested {}
            }
            struct Internal {}
            """,
            "Extensions.swift": """
            public extension Visible {
                var value: Int { borrow { 42 } }
                private var privateValue: Int { borrow { 42 } }
                fileprivate var fileValue: Int { borrowing get { 42 } }
                internal var internalValue: Int { consuming get { 42 } }
                package var packageValue: Int { borrow { 42 } }
                private struct ExtensionHidden: ~Copyable {
                    public var value: Int { borrow { 42 } }
                }
            }
            public extension Visible.Nested {
                var value: Int { borrowing get { 42 } }
            }
            public extension Visible.HiddenNested {
                var value: Int { borrow { 42 } }
                struct Child: ~Copyable {}
            }
            public extension Visible.InternalNested {
                var value: Int { borrow { 42 } }
            }
            public extension Hidden {
                var value: Int { borrowing get { 42 } }
            }
            public extension Hidden.Nested {
                var value: Int { borrow { 42 } }
            }
            extension Internal {
                public var value: Int { consuming get { 42 } }
            }
            """,
        ])

        #expect(
            records == [
                "Fixture.Visible.value\tborrow",
                "Fixture.Visible.Nested.value\tborrowing get",
            ])
    }

    @Test
    func distinguishesAccessorKindsFromGetterModifiers() throws {
        let records = try ownershipRecords(sources: [
            "AccessorKinds.swift": """
            public struct AccessorKinds {
                private var stored: Int
                public var borrowed: Int {
                    borrowing get { stored }
                    nonmutating set {}
                }
                public var consumed: Int { consuming get { 42 } }
                public var plain: Int { get { 42 } }
                public var mutatingGetter: Int { mutating get { 42 } }
                public var nonmutatingGetter: Int { nonmutating get { 42 } }
                public var projection: Int {
                    mutating borrow { stored }
                    nonmutating mutate { &stored }
                }
                public private(set) var restricted: Int {
                    borrow { stored }
                    mutate { &stored }
                }
                public private(set) var restrictedGetter: Int {
                    borrowing get { stored }
                    set { stored = newValue }
                }
            }
            """
        ])

        #expect(
            records == [
                "Fixture.AccessorKinds.borrowed\tborrowing get",
                "Fixture.AccessorKinds.consumed\tconsuming get",
                "Fixture.AccessorKinds.projection\tborrow",
                "Fixture.AccessorKinds.projection\tmutate",
                "Fixture.AccessorKinds.restricted\tborrow",
                "Fixture.AccessorKinds.restrictedGetter\tborrowing get",
            ])
    }

    @Test
    func ignoresOwnershipWordsInCommentsAndLiterals() throws {
        let records = try ownershipRecords(sources: [
            "Noise.swift": #"""
            // public struct Phantom: ~Copyable { public var value: Int { borrow { 42 } } }
            /* public extension Noise { var value: Int { consuming get { 42 } } } */
            public struct Noise {
                public let text = "public var value: Int { borrow { 42 } mutate { &stored } }"
                public let multiline = """
                    public struct Phantom: ~Copyable {
                        public var value: Int { borrowing get { 42 } }
                    }
                    """
            }
            """#
        ])

        #expect(records.isEmpty)
    }

    private func ownershipRecords(sources: [String: String]) throws -> Set<String> {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-api-ownership-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                Issue.record("Fixture cleanup failed: \(error)")
            }
        }
        for (name, source) in sources {
            try source.write(
                to: root.appendingPathComponent(name), atomically: true, encoding: .utf8
            )
        }

        let runner = ProcessRunner()
        let compiler = try SwiftToolchain(runner: runner).swiftCompilerExecutable(
            environment: runner.environment
        )
        let report = try SourceOwnershipAPIBaseline(
            runner: runner, swiftCompilerExecutable: compiler
        ).render(moduleSources: ["Fixture": root])
        return Set(report.split(separator: "\n").filter { $0.contains("\t") }.map(String.init))
    }
}
