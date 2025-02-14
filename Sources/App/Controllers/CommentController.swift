import Fluent
import Vapor

struct CommentController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api")
        let discussions = api.grouped("discussions")
        let discussionId = discussions.grouped(":discussionId")
        let comments = discussionId.grouped("comments")
        let protected = comments.grouped(AuthMiddleware())
        // comments.group("api", ":discussionId", "comments") { comment in
        //     comment.get(use: getComments)
        //     comment.post(use: addComment)
        //     comment.delete(use: deleteComment)
        // }
        protected.post("add", use: addComment)
        protected.delete("delete", ":commentId", use: deleteComment)
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

        return comment
    }

    @Sendable
    func deleteComment(_ req: Request) async throws -> Response {
        let discussionId = try req.parameters.require("discussionId")
        let commentId = try req.parameters.require("commentId")

        let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
        guard let _ = discussion else {
            throw Abort(.notFound, reason: "Discussion not found")
        }

        let comment = try await Comment.find(UUID(uuidString: commentId), on: req.db)
        guard let comment = comment else {
            throw Abort(.notFound, reason: "Comment not found")
        }

        try await comment.delete(on: req.db)

        return req.redirect(to: "/api/discussions/\(discussionId)/comments")
    }
}
