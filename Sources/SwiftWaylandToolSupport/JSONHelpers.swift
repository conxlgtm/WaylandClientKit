import Foundation

public enum JSONHelpers {
    public static func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ToolError(
                "malformed JSON in \(url.path): \(error)",
                exitCode: ToolExitCode.data
            )
        }
    }

    public static func loadObject(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let value = try JSONSerialization.jsonObject(with: data)
        guard let object = value as? [String: Any] else {
            throw ToolError("JSON root must be an object: \(url.path)", exitCode: ToolExitCode.data)
        }
        return object
    }
}

