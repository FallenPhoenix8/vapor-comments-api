import Fluent

public struct CreateDiscussion: AsyncMigration {
    public func prepare(on database: Database) async throws {
        try await database.schema("discussions")
            .id()
            .field("title", .string, .required)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("discussions").delete()
    }
}
