import Foundation

public enum SanitizerOptions {
    public static func threadSanitizerOptions(
        suppressions: URL,
        inherited environment: [String: String]
    ) -> String {
        appendSanitizerOptions(
            environment["TSAN_OPTIONS"],
            required: [
                "detect_deadlocks=0",
                "suppressions=\(suppressions.path)",
            ])
    }

    public static func appendSanitizerOptions(
        _ inherited: String?,
        required: [String]
    ) -> String {
        let requiredOptions = required.joined(separator: ":")
        guard
            let inherited,
            !inherited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return requiredOptions
        }
        return "\(inherited):\(requiredOptions)"
    }
}
