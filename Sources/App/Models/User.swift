import Fluent
import JWT
import Vapor

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "passwordHash")
    var passwordHash: String

    init() {}

    init(id: UUID? = nil, username: String, passwordHash: String) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
    }
}

extension User {
    struct Migration: AsyncMigration {
        var name: String { "CreateUser" }
        public func prepare(on database: Database) async throws {
            try await database.schema("users")
                .id()
                .field("username", .string, .required)
                .unique(on: "username")
                .field("passwordHash", .string, .required)
                .create()
        }

        public func revert(on database: Database) async throws {
            try await database.schema("users").delete()
        }
    }
}

extension User {
    struct Create: Content {
        var username: String
        var password: String
        var confirmPassword: String
    }

    struct Login: Content {
        var username: String
        var password: String
    }
}

extension User.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("username", as: String.self, is: !.empty)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$username
    static let passwordHashKey = \User.$passwordHash

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: passwordHash)
    }
}

extension User {
    struct Payload: JWTPayload {
        // Maps the longer Swift property names to the
        // shortened keys used in the JWT payload.
        enum CodingKeys: String, CodingKey {
            case subject = "sub"
            case expiration = "exp"
        }

        // The "sub" (subject) claim identifies the principal that is the
        // subject of the JWT.
        var subject: SubjectClaim

        // The "exp" (expiration time) claim identifies the expiration time on
        // or after which the JWT MUST NOT be accepted for processing.
        var expiration: ExpirationClaim

        // Run any additional verification logic beyond
        // signature verification here.
        // Since we have an ExpirationClaim, we will
        // call its verify method.
        func verify(using _: some JWTAlgorithm) async throws {
            try expiration.verifyNotExpired()
        }
    }
}
