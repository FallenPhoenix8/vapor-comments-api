import Fluent

// public struct CreateUser: AsyncMigration {
//     public func prepare(on database: Database) async throws {
//         try await database.schema("users")
//             .id()
//             .field("username", .string, .required, .unique(on: "psql"))
//             .field("passwordHash", .string, .required)
//             .create()
//     }

//     public func revert(on database: Database) async throws {
//         try await database.schema("users").delete()
//     }
// }
