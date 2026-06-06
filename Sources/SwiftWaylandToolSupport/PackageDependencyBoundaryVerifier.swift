import Foundation

public struct PackageDependencyBoundaryVerifier {
    public let forbiddenExternalProducts: Set<String>
    public let forbiddenExternalPackages: Set<String>
    public let forbiddenTargets: Set<String>
    public let protectedProductTargets: [String: [String]]

    public init(
        forbiddenExternalProducts: Set<String> = ["ArgumentParser"],
        forbiddenExternalPackages: Set<String> = ["swift-argument-parser"],
        forbiddenTargets: Set<String> = ["SwiftWaylandTool", "SwiftWaylandToolSupport"],
        protectedProductTargets: [String: [String]] = [
            "WaylandClient": ["WaylandClient"],
            "WaylandGraphicsPreview": ["WaylandGraphicsPreview"],
        ]
    ) {
        self.forbiddenExternalProducts = forbiddenExternalProducts
        self.forbiddenExternalPackages = forbiddenExternalPackages
        self.forbiddenTargets = forbiddenTargets
        self.protectedProductTargets = protectedProductTargets
    }

    public func verify(packageDump: String) throws {
        guard let data = packageDump.data(using: .utf8) else {
            throw ToolError("package dump is not UTF-8", exitCode: ToolExitCode.data)
        }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any],
            let targetObjects = root["targets"] as? [[String: Any]]
        else {
            throw ToolError("package dump is missing targets", exitCode: ToolExitCode.data)
        }

        var targets: [String: [PackageDependency]] = [:]
        for target in targetObjects {
            guard let name = target["name"] as? String else { continue }
            let dependencies = (target["dependencies"] as? [[String: Any]] ?? [])
                .compactMap(PackageDependency.init)
            targets[name] = dependencies
        }

        var failures: [String] = []
        for product in protectedProductTargets.keys.sorted() {
            let roots = protectedProductTargets[product] ?? []
            for target in roots {
                walk(
                    target: target,
                    product: product,
                    targets: targets,
                    visited: [],
                    failures: &failures)
            }
        }

        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
    }

    private func walk(
        target: String,
        product: String,
        targets: [String: [PackageDependency]],
        visited: Set<String>,
        failures: inout [String]
    ) {
        guard !visited.contains(target) else { return }
        var nextVisited = visited
        nextVisited.insert(target)

        if forbiddenTargets.contains(target) {
            failures.append(
                "\(product) dependency graph includes tool-only target \(target). "
                    + "Keep maintainer tooling out of public library products.")
        }

        for dependency in targets[target] ?? [] {
            switch dependency {
            case .target(let name):
                if targets[name] != nil {
                    walk(
                        target: name,
                        product: product,
                        targets: targets,
                        visited: nextVisited,
                        failures: &failures)
                } else if forbiddenExternalProducts.contains(name) {
                    failures.append(
                        "\(product) dependency graph includes forbidden external product \(name). "
                            + "Keep tool-only dependencies behind SwiftWaylandTool.")
                }
            case .product(let name, let package):
                let packageIsForbidden = package.map(forbiddenExternalPackages.contains) ?? false
                if forbiddenExternalProducts.contains(name) || packageIsForbidden {
                    let packageSuffix = package.map { " from \($0)" } ?? ""
                    failures.append(
                        "\(product) dependency graph includes forbidden external product "
                            + "\(name)\(packageSuffix). "
                            + "Keep tool-only dependencies behind SwiftWaylandTool.")
                }
            }
        }
    }
}

private enum PackageDependency {
    case target(String)
    case product(String, package: String?)

    init?(object: [String: Any]) {
        if let values = object["byName"] as? [Any],
            let name = values.first as? String
        {
            self = .target(name)
            return
        }
        if let values = object["product"] as? [Any],
            let name = values.first as? String
        {
            let package = values.dropFirst().compactMap { $0 as? String }.first
            self = .product(name, package: package)
            return
        }
        if let values = object["target"] as? [Any],
            let name = values.first as? String
        {
            self = .target(name)
            return
        }
        return nil
    }
}
