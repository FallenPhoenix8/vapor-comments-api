import Fluent

public struct CreatePost: AsyncMigration {
    public func prepare(on database: Database) async throws {
        try await database.schema("posts")
            .id()
            .field("title", .string, .required)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("posts").delete()
    }
}
