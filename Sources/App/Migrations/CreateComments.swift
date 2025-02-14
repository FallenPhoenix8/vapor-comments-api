import Fluent

public struct CreateComments: AsyncMigration {
    public func prepare(on database: Database) async throws {
        try await database.schema("comments")
            .id()
            .field("content", .string, .required)
            .field("discussionId", .uuid, .required, .references("discussions", "id"))
            .field("participantId", .uuid, .required, .references("participants", "id"))
            .field("createdAt", .datetime, .required)
            .field("updatedAt", .datetime, .required)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("comments").delete()
    }
}
