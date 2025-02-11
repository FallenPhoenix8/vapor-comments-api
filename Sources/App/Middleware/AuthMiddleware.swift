import Vapor

struct AuthMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let token = req.session.data["token"] else {
            throw Abort(.unauthorized, reason: "No token found in session")
        }

        _ = try await req.jwt.verify(token, as: User.Payload.self)
        return try await next.respond(to: req)
    }
}
