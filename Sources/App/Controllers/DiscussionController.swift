import Fluent
import Vapor

struct DiscussionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(AuthMiddleware())
        routes.get("api", "discussions", use: index)
        protected.post("api", "discussions", "create", ":title", use: create)
        protected.delete("api", "discussions", "delete", ":discussionId", use: delete)
    }

    @Sendable
    func index(_ req: Request) async throws -> [Discussion] {
        return try await Discussion.query(on: req.db).all()
    }

    @Sendable
    func create(_ req: Request) async throws -> Response {
        guard let title = req.parameters.get("title") else {
            throw Abort(.badRequest, reason: "Missing title")
        }

        let discussion = try Discussion(title: title, userId: await req.user().$id.value!)

        try await discussion.save(on: req.db)

        let discussionDict = discussion.toDictionary()
        let json = try JSONEncoder().encode(discussionDict)

        let res = Response(status: .created, headers: ["Content-Type": "application/json"], body: .init(data: json))
        return res
    }

    @Sendable
    func delete(_ req: Request) async throws -> Response {
        let discussionId = try req.parameters.require("discussionId")

        let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
        guard let discussion = discussion else {
            throw Abort(.notFound, reason: "Discussion not found")
        }

        try await discussion.delete(on: req.db)
        // let discussions = try await Discussion.query(on: req.db).all()
        // let discussionsJSON: [[String: String]] = discussions.map { discussion in
        //     discussion.toDictionary()
        // }
        // let jsonData = try JSONEncoder().encode(discussionsJSON)
        // let res = Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: jsonData))

        return req.redirect(to: "/api/discussions")
    }
}
