import Fluent

public struct CreateComment: AsyncMigration {
    public func prepare(on database: Database) async throws {
        try await database.schema("comments")
            .id()
            .field("content", .string, .required)
            .field("postId", .int, .required)
            .field("userId", .int, .required)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("comments").delete()
    }
}
