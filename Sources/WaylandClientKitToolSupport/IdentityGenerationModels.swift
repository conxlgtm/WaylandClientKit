struct IdentityDescriptionPolicy: Decodable {
    private enum CodingKeys: String, CodingKey {
        case access
        case prefix
        case expression
        case inExtension
    }

    let access: IdentityAccess?
    let prefix: String?
    let expression: String?
    let inExtension: Bool

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        access = try values.decodeIfPresent(IdentityAccess.self, forKey: .access)
        prefix = try values.decodeIfPresent(String.self, forKey: .prefix)
        expression = try values.decodeIfPresent(String.self, forKey: .expression)
        inExtension = try values.decodeIfPresent(Bool.self, forKey: .inExtension) ?? false
    }

    func effectiveAccess(typeAccess: IdentityAccess) -> IdentityAccess { access ?? typeAccess }
}

struct IdentityIntegerLiteralPolicy: Decodable {
    private enum CodingKeys: String, CodingKey {
        case access
        case type
        case assignDirectly
        case typealiasAccess
    }

    let access: IdentityAccess
    let type: String?
    let assignDirectly: Bool
    let typealiasAccess: IdentityAccess?

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        access = try values.decode(IdentityAccess.self, forKey: .access)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        assignDirectly = try values.decodeIfPresent(Bool.self, forKey: .assignDirectly) ?? false
        typealiasAccess = try values.decodeIfPresent(
            IdentityAccess.self,
            forKey: .typealiasAccess
        )
    }
}

struct IdentityInitializerOverride: Decodable {
    let access: IdentityAccess
    let label: String
    let parameter: String
    let type: String
    let expression: String
}

struct IdentityDocumentationPolicy: Decodable {
    let summary: String
    let storage: String?
    let constructor: String?
    let description: String?
    let integerLiteral: String?
    let integerLiteralType: String?
}

enum IdentityAccess: String, Codable, Comparable {
    case `public`, package, `internal`, `fileprivate`, `private`

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }

    private var rank: Int {
        switch self {
        case .public: 0
        case .package: 1
        case .internal: 2
        case .fileprivate: 3
        case .private: 4
        }
    }
}

enum IdentityAuditCategory: String, Codable {
    case rawProtocolIdentity = "raw protocol identity"
    case clientIdentity = "client identity"
    case publicProjection = "public projection"
    case displayOwnedHandleIdentity = "display-owned handle identity"
    case seatScopedIdentity = "seat-scoped identity"
    case opaqueProtocolToken = "opaque protocol token"
    case applicationIdentity = "application identity"
}

struct IdentityAuditManifest: Codable {
    let identities: [IdentityAuditEntry]
}

struct IdentityAuditEntry: Codable {
    let type: String
    let category: IdentityAuditCategory
    let constructor: IdentityAccess
    let storage: String
    let storageVisibility: IdentityAccess
}
