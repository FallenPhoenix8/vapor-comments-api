import Fluent
import Vapor

final class Discussion: Model, Content, @unchecked Sendable, Codable {
  static let schema = "discussions"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "title")
  var title: String

  @Field(key: "picture")
  var picture: String?

  @Timestamp(key: "createdAt", on: .create)
  var createdAt: Date?

  @Timestamp(key: "updatedAt", on: .update)
  var updatedAt: Date?

  @Parent(key: "userId")
  var author: User

  @Children(for: \.$discussion)
  var comments: [Comment]

  @Children(for: \.$discussion)
  var participants: [Participant]

  init() {}

  init(
    id: UUID? = nil, title: String, createdAt: Date? = nil, updatedAt: Date? = nil,
    picture: String? = nil, authorId: User.IDValue
  ) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    $author.id = authorId
    self.picture = picture
  }
}

extension Discussion {
  struct Migration: AsyncMigration {
    var name: String { "CreateDiscussion" }
    public func prepare(on database: Database) async throws {
      try await database.schema("discussions")
        .id()
        .field("title", .string, .required)
        .field("createdAt", .datetime, .required)
        .field("updatedAt", .datetime, .required)
        .field("userId", .uuid, .required, .references("users", "id"))
        .field("picture", .string)
        .unique(on: "title")
        .create()
    }

    public func revert(on database: Database) async throws {
      try await database.schema("discussions").delete()
    }
  }
}

extension Discussion {
  func getJSONData() -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return try! encoder.encode(self)
  }

  static func getDetails(request: Request, discussionId: UUID) async throws -> Discussion {
    let discussion = try await Discussion.query(on: request.db)
      .filter(\.$id == discussionId)
      .with(\.$author)
      .with(\.$participants)
      .with(\.$comments)
      .first()

    guard let discussion = discussion else {
      throw Abort(.notFound, reason: "Discussion not found")
    }
    return discussion
  }

  static func isTitleTaken(_ title: String, on: any Database) async throws -> Bool {
    let discussion = try await Discussion.query(on: on)
      .filter(\.$title == title)
      .first()

    return discussion != nil
  }
}
