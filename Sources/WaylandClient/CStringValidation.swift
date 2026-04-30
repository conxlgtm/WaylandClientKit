enum CStringValidation {
    static func requireNoInteriorNUL(
        _ value: String,
        fieldName: String
    ) throws {
        guard !value.contains("\0") else {
            throw ClientError.invalidWindowConfiguration(
                "\(fieldName) must not contain embedded NUL bytes"
            )
        }
    }

    static func requireNonEmptyNoInteriorNUL(
        _ value: String,
        fieldName: String,
        error: (String) -> ClientError
    ) throws {
        guard !value.isEmpty else {
            throw error("\(fieldName) must not be empty")
        }

        guard !value.contains("\0") else {
            throw error("\(fieldName) must not contain embedded NUL bytes")
        }
    }
}
