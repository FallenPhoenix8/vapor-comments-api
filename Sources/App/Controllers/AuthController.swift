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

        protected.get("is-authenticated", use: isAuthenticated)
        auth.get("username-exists", use: isUsernameExists)
    }

    func setSessionToken(request: Request, userUuid: UUID, isRegister: Bool = false) async throws -> Response {
        let expiration = Date().addingTimeInterval(60 * 60 * 24 * 7 /* 7 days */ )
        let payload = User.Payload(
            subject: SubjectClaim(value: userUuid.uuidString),
            expiration: .init(value: expiration)
        )
        let token = try await request.jwt.sign(payload)

        request.headers.bearerAuthorization = .init(token: token)
        request.session.data["token"] = token
        print(request.session.data)

        let json: [String: Any] = [
            "token": token,
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
        return req.redirect(to: "/")
    }

    @Sendable func deleteMe(req: Request) async throws -> Response {
        let user = try await req.user()
        try await user.delete(on: req.db)
        return req.redirect(to: "/")
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
        if let _ = user {
            dictionary["exists"] = true
            let jsonData = try JSONEncoder().encode(dictionary)

            return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: jsonData))
        } else {
            dictionary["exists"] = false
            let jsonData = try JSONEncoder().encode(dictionary)

            return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: jsonData))
        }
    }
}
