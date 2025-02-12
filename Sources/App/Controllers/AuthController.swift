import Fluent
import JWT
import Vapor

final class AuthController: RouteCollection, Sendable {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        let protected = auth.grouped(AuthMiddleware())

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
    }

    func setSessionToken(request: Request, userUuid: UUID) async throws -> [String: String] {
        let expiration = Date().addingTimeInterval(60 * 60 * 24 * 7 /* 7 days */ )
        let payload = User.Payload(
            subject: SubjectClaim(value: userUuid.uuidString),
            expiration: .init(value: expiration)
        )
        let token = try await request.jwt.sign(payload)

        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.session.data["token"] = token

        return ["token": token]
    }

    @Sendable
    func register(req: Request) async throws -> [String: String] {
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

        return try await setSessionToken(request: req, userUuid: userUuid)
    }

    @Sendable
    func login(req: Request) async throws -> [String: String] {
        let loginData = try req.content.decode(User.Login.self)

        guard let user = try await User.query(on: req.db)
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
    func getMe(req: Request) async throws -> String {
        let user = try await req.user()

        return user.$username.value!
    }

    @Sendable func logout(req: Request) async throws -> Response {
        req.session.data["token"] = nil
        req.session.destroy()
        return req.redirect(to: "/")
    }

    @Sendable func deleteMe(req: Request) async throws -> Response {
        let user = try await req.user()
        try await user.delete(on: req.db)
        return req.redirect(to: "/")
    }
}
