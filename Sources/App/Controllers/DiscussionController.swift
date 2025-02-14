import Fluent
import Vapor

struct DiscussionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api")
        let discussions = api.grouped("discussions")
        let protected = discussions.grouped(AuthMiddleware())
        discussions.get(use: index)
        protected.post("create", ":title", use: create)
        protected.delete(":discussionId", "delete", use: delete)
        protected.delete(":discussionId", "leave", use: leave)
        protected.post(":discussionId", "join", use: join)
        protected.get(":discussionId", "details", use: getDetails)
    }

    @Sendable
    func index(_ req: Request) async throws -> [Discussion] {
        return try await Discussion.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()
    }

    @Sendable
    func create(_ req: Request) async throws -> Response {
        guard let title = req.parameters.get("title") else {
            throw Abort(.badRequest, reason: "Missing title")
        }

        let user = try await req.user()

        let discussion = Discussion(title: title, authorId: user.$id.value!)

        try await discussion.save(on: req.db)

        let participant = try Participant(discussionId: discussion.requireID(), userId: user.requireID(), isAuthor: true)
        try await participant.save(on: req.db)

        return req.redirect(to: "/api/discussions")
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

    @Sendable
    func join(_ req: Request) async throws -> Response {
        let discussionId = try req.parameters.require("discussionId")

        let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
        guard let discussion = discussion else {
            throw Abort(.notFound, reason: "Discussion not found")
        }

        let user = try await req.user()
        let testParticipant = try await Participant.query(on: req.db)
            .filter(\.$discussion.$id == discussion.requireID())
            .filter(\.$user.$id == user.requireID())
            .first()

        guard testParticipant == nil else {
            throw Abort(.badRequest, reason: "User already joined discussion")
        }

        let participant = try Participant(discussionId: discussion.requireID(), userId: user.requireID(), isAuthor: false)

        try await participant.save(on: req.db)

        return Response(status: .ok, body: .init(string: "Successfully joined discussion"))
    }

    @Sendable
    func getDetails(_ req: Request) async throws -> Discussion {
        let discussionId = try req.parameters.require("discussionId")

        let discussion = try await Discussion.query(on: req.db)
            .filter(\.$id == UUID(uuidString: discussionId) ?? UUID())
            .with(\.$author)
            .with(\.$participants)
            .with(\.$comments)
            .first()

        guard let discussion = discussion else {
            throw Abort(.notFound, reason: "Discussion not found")
        }

        let isDiscussionIncludesUser = try await Participant.query(on: req.db)
            .filter(\.$discussion.$id == discussion.requireID())
            .filter(\.$user.$id == req.user().requireID())
            .first() != nil

        if !isDiscussionIncludesUser {
            throw Abort(.unauthorized, reason: "User is not a participant of discussion")
        }

        return discussion
    }

    @Sendable
    func leave(_ req: Request) async throws -> Response {
        let discussionId = try req.parameters.require("discussionId")

        let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
        guard let discussion = discussion else {
            throw Abort(.notFound, reason: "Discussion not found")
        }

        let user = try await req.user()
        let participant = try await Participant.query(on: req.db)
            .filter(\.$discussion.$id == discussion.requireID())
            .filter(\.$user.$id == user.requireID())
            .first()

        guard let participant = participant else {
            throw Abort(.notFound, reason: "Participant not found")
        }

        try await participant.delete(on: req.db)

        return Response(status: .ok, body: .init(string: "Successfully left discussion"))
    }
}
