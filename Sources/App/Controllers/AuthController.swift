import Fluent
import JWT
import Vapor

/// Auth Routes
/// POST /api/auth/register: Register a new user with parameters:
///   - username: String
///   - password: String
///   - confirmPassword: String

/// GET /api/auth/register: Method not allowed

/// Discussion Routes
/// GET /api/discussions: Get all discussions
/// GET /api/discussions/is-title-taken/:title: Check if a discussion title is taken

/// POST /api/discussions/create/:title: Create a new discussion (Protected Route)

/// DELETE /api/discussions/:discussionId/delete: Delete a discussion (Protected Route)

/// DELETE /api/discussions/:discussionId/leave: Leave a discussion (Protected Route)

/// POST /api/discussions/:discussionId/join: Join a discussion (Protected Route)

/// GET /api/discussions/:discussionId/details: Get details of a discussion (Protected Route)

/// WebSocket /api/discussions/:discussionId/ws: WebSocket for discussion updates (Protected Route)

/// GET /api/discussions/:discussionId/is-participant: Check if user is a participant (Protected Route)

/// Comment Routes
/// POST /api/discussions/:discussionId/comments/add: Add a comment to a discussion (Protected Route)

/// DELETE /api/discussions/:discussionId/comments/delete/:commentId: Delete a comment (Protected Route)

/// Participant Routes
/// GET /api/discussions/:discussionId/participants/:participantId: Get participant by ID (Protected Route)

/// GET /api/discussions/:discussionId/participants/user/:userId: Get participant by user ID (Protected Route)

final class AuthController: RouteCollection, Sendable {
  func boot(routes: RoutesBuilder) throws {
    let auth = routes.grouped("auth")
    let protected = auth.grouped(AuthMiddleware())
    let users = routes.grouped("users")

    auth.post("register", use: register)
    auth.get("register") { _ throws -> Response in
      throw Abort(.methodNotAllowed)
    }

    auth.post("login", use: login)
    auth.get("login") { _ throws -> Response in
      throw Abort(.methodNotAllowed)
    }

    protected.post("logout", use: logout)
    protected.get("logout", use: logout)

    protected.delete("me", use: deleteMe)
    protected.get("me", use: getMe)

    protected.get("is-authenticated", use: isAuthenticated)
    auth.get("username-exists", use: isUsernameExists)

    users.get(":userUuid", use: getUserByUuid)
  }

  func setSessionToken(request: Request, userUuid: UUID, isRegister: Bool = false) async throws
    -> Response
  {
    let expiration = Date().addingTimeInterval(60 * 60 * 24 * 7 /* 7 days */)
    let payload = User.Payload(
      subject: SubjectClaim(value: userUuid.uuidString),
      expiration: .init(value: expiration)
    )
    let token = try await request.jwt.sign(payload)

    request.headers.bearerAuthorization = .init(token: token)
    request.session.data["token"] = token
    // print(request.session.data)

    let json: [String: Any] = [
      "token": token
    ]
    let jsonData = try JSONSerialization.data(withJSONObject: json)
    let resStatus: HTTPStatus = isRegister ? .created : .ok
    // let resHeaders: HTTPHeaders = ["Content-Type": "application/json", "Access-Control-Allow-Origin": "*", "Set-Cookie": "token=\(token); Max-Age=604800; Path=/"]
    let res: Response = .init(status: resStatus, body: .init(data: jsonData))

    res.headers.replaceOrAdd(name: .contentType, value: "application/json")
    // res.headers.replaceOrAdd(name: .accessControlAllowOrigin, value: Environment.get("FRONTEND_URL") ?? "*")
    // res.headers.replaceOrAdd(name: .accessControlAllowCredentials, value: "true")

    return res
  }

  @Sendable
  func register(req: Request) async throws -> Response {
    try User.Create.validate(content: req)
    let create = try req.content.decode(User.Create.self)

    guard create.password == create.confirmPassword else {
      throw Abort(.badRequest, reason: "Passwords do not match")
    }

    let user = try User(username: create.username, passwordHash: Bcrypt.hash(create.password))
    try await user.save(on: req.db)

    guard let userUuid = user.$id.value else {
      throw Abort(.internalServerError, reason: "Creating user failed")
    }

    return try await setSessionToken(request: req, userUuid: userUuid, isRegister: true)
  }

  @Sendable
  func login(req: Request) async throws -> Response {
    let loginData = try req.content.decode(User.Login.self)

    guard
      let user = try await User.query(on: req.db)
        .filter(\.$username == loginData.username).first()
    else {
      throw Abort(.unauthorized, reason: "User not found")
    }

    guard try user.verify(password: loginData.password) else {
      throw Abort(.unauthorized, reason: "Incorrect password")
    }

    guard let userUuid = user.$id.value else {
      throw Abort(.unauthorized, reason: "User not found")
    }

    return try await setSessionToken(request: req, userUuid: userUuid)
  }

  @Sendable
  func getMe(req: Request) async throws -> [String: String] {
    let user = try await req.user()

    return [
      "id": user.$id.value!.uuidString,
      "username": user.$username.value!,
    ]
  }

  @Sendable func logout(req: Request) async throws -> Response {
    req.session.data["token"] = nil
    req.session.destroy()

    req.headers.bearerAuthorization = nil
    // req.cookies["token"] = HTTPCookies.Value(
    //     string: "",
    //     expires: Date(timeIntervalSince1970: 0),
    //     maxAge: 0,
    //     domain: nil,
    //     path: "/",
    //     isSecure: true,
    //     isHTTPOnly: true,
    //     sameSite: .lax
    // )

    // print(req.cookies)
    return Response(status: .ok)
  }

  @Sendable func deleteMe(req: Request) async throws -> Response {
    let user = try await req.user()
    try await user.delete(on: req.db)
    return Response(status: .ok)
  }

  @Sendable func isAuthenticated(req: Request) async -> Response {
    do {
      _ = try await req.user()
      return Response(status: .ok, body: .init(string: "true"))
    } catch {
      return Response(status: .unauthorized, body: .init(string: "false"))
    }
  }

  @Sendable func isUsernameExists(req: Request) async throws -> Response {
    guard let username = try? req.query.get(String.self, at: "username") else {
      throw Abort(.badRequest, reason: "username is missing")
    }

    if username.isEmpty {
      throw Abort(.badRequest, reason: "username is empty")
    }

    var dictionary: [String: Bool] = [:]

    let user = try await req.db.query(User.self).filter(\.$username == username).first()
    if user != nil {
      dictionary["exists"] = true
      let jsonData = try JSONEncoder().encode(dictionary)

      return Response(
        status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: jsonData))
    } else {
      dictionary["exists"] = false
      let jsonData = try JSONEncoder().encode(dictionary)

      return Response(
        status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: jsonData))
    }
  }

  @Sendable func getUserByUuid(req: Request) async throws -> Response {
    let uuid = try req.parameters.require("userUuid")
    let userUuid = UUID(uuidString: uuid)
    guard let userUuid = userUuid else {
      throw Abort(.badRequest, reason: "Invalid UUID")
    }

    let user = try await req.db.query(User.self).filter(\.$id == userUuid).first()
    guard let user = user else {
      throw Abort(.unauthorized, reason: "User not found")
    }
    let json: [String: Any] = [
      "id": user.$id.value!.uuidString,
      "username": user.$username.value!,
      "profilePicture": user.$profilePicture.value! ?? "null",
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: json)
    return Response(
      status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: jsonData))
  }
}
