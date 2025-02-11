import Fluent

public struct CreateComments: AsyncMigration {
    public func prepare(on database: Database) async throws {
        try await database.schema("comments")
            .id()
            .field("content", .string, .required)
            .field("discussionId", .uuid, .required, .references("discussions", "id"))
            .field("userId", .uuid, .required, .references("users", "id"))
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("comments").delete()
    }
}
