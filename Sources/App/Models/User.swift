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

  @Field(key: "profilePicture")
  var profilePicture: String?

  @Children(for: \.$user)
  var participants: [Participant]

  init() {}

  init(id: UUID? = nil, username: String, passwordHash: String, profilePicture: String? = nil) {
    self.id = id
    self.username = username
    self.passwordHash = passwordHash
    self.profilePicture = profilePicture
  }

  init(request: Request) async throws {
    // let token = request.cookies["token"]?.string ?? request.session.data["token"] ?? request.headers.bearerAuthorization!.token

    let token = request.session.data["token"] ?? request.headers.bearerAuthorization!.token

    let payload = try await request.jwt.verify(token, as: User.Payload.self)
    id = UUID(uuidString: payload.subject.value)
    guard let user = try await User.query(on: request.db).filter(\.$id == id!).first() else {
      throw Abort(.internalServerError, reason: "User not found")
    }

    username = user.username
    passwordHash = user.passwordHash
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
        .field("profilePicture", .string)
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

extension User: ModelAuthenticatable, Authenticatable {
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

extension Request {
  func user() async throws -> User {
    return try await User(request: self)
  }
}
