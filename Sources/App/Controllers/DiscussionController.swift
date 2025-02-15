import Fluent
import Vapor

let store = WebSocketManagerStore()

func broadcastUpdate(_ req: Request, discussionId: UUID) async throws {
    let discussionDetails = try await Discussion.getDetails(request: req, discussionId: discussionId)

    let wsManager = await store.getWebSocket(for: discussionId)

    if let wsManager = wsManager {
        wsManager.broadcast(discussionDetails.getJSONData())
    }
}

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
        protected.webSocket(":discussionId", "ws") { req, ws in
            await wsDiscussion(req, ws: ws, store: store)
        }

        // comments
        let discussionId = discussions.grouped(":discussionId")
        let comments = discussionId.grouped("comments")
        let protectedComments = comments.grouped(AuthMiddleware())
        protectedComments.post("add", use: addComment)
        protectedComments.delete("delete", ":commentId", use: deleteComment)
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

        try await broadcastUpdate(req, discussionId: discussion.requireID())

        return Response(status: .ok, body: .init(string: "Successfully joined discussion"))
    }

    @Sendable
    func getDetails(_ req: Request) async throws -> Discussion {
        let discussionId = try req.parameters.require("discussionId")

        let discussion = try await Discussion.getDetails(request: req, discussionId: UUID(uuidString: discussionId) ?? UUID())

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

        try await broadcastUpdate(req, discussionId: discussion.requireID())

        return Response(status: .ok, body: .init(string: "Successfully left discussion"))
    }

    @Sendable
    func wsDiscussion(_ req: Request, ws: WebSocket, store: WebSocketManagerStore) async {
        do {
            let discussionDetails = try await getDetails(req)

            let discussionManager = try WebSocketManager(threadLabel: discussionDetails.requireID().uuidString)
            discussionManager.addConnection(ws)
            let discussionId = try discussionDetails.requireID()

            // Safely add the WebSocketManager to the store
            await store.addWebSocket(for: discussionId, manager: discussionManager)

        } catch {
            print("ERROR CREATING DISCUSSION WEBSOCKET: \(error)")
        }
    }

    @Sendable
    func addComment(_ req: Request) async throws -> Comment {
        let discussionId = try req.parameters.require("discussionId")
        let content = try req.query.get(String.self, at: "content")

        let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
        guard let discussion = discussion else {
            throw Abort(.notFound, reason: "Discussion not found")
        }

        let user = try await req.user()
        let userId = try user.requireID()

        let participant = try await Participant.query(on: req.db)
            .filter(\.$discussion.$id == discussion.requireID())
            .filter(\.$user.$id == userId)
            .first()

        guard let participant = participant else {
            throw Abort(.notFound, reason: "Participant not found")
        }

        let comment = try Comment(content: content, discussionId: discussion.requireID(), participantId: participant.requireID())

        try await comment.save(on: req.db)

        try await broadcastUpdate(req, discussionId: discussion.requireID())

        return comment
    }

    @Sendable
    func deleteComment(_ req: Request) async throws -> Response {
        let discussionId = try req.parameters.require("discussionId")
        let commentId = try req.parameters.require("commentId")

        let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
        guard let discussion = discussion else {
            throw Abort(.notFound, reason: "Discussion not found")
        }

        let comment = try await Comment.find(UUID(uuidString: commentId), on: req.db)
        guard let comment = comment else {
            throw Abort(.notFound, reason: "Comment not found")
        }

        try await comment.delete(on: req.db)

        try await broadcastUpdate(req, discussionId: discussion.requireID())

        return req.redirect(to: "/api/discussions/\(discussionId)/comments")
    }
}
