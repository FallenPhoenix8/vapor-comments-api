import Fluent

public struct CreateDiscussion: AsyncMigration {
    public func prepare(on database: Database) async throws {
        try await database.schema("discussions")
            .id()
            .field("title", .string, .required)
            .field("createdAt", .datetime, .required)
            .field("updatedAt", .datetime, .required)
            .field("userId", .uuid, .required, .references("users", "id"))
            .unique(on: "title")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("discussions").delete()
    }
}
