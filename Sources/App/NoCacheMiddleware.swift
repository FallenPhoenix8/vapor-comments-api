import Vapor

struct NoCacheMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        return next.respond(to: request).map { response in
            response.headers.cacheControl = .init(mustRevalidated: true, noCache: true, noStore: true, maxAge: 0)
            return response
        }
    }
}
