import Vapor

struct AuthMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        var token = req.session.data["token"]
        if token == nil {
            token = req.headers.bearerAuthorization?.token
        }

        guard let token = token else {
            throw Abort(.unauthorized, reason: "No token found in session or headers")
        }

        _ = try await req.jwt.verify(token, as: User.Payload.self)
        return try await next.respond(to: req)
    }
}
