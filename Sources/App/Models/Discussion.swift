import Fluent
import Vapor

final class Discussion: Model, Content, @unchecked Sendable, Codable {
    static let schema = "discussions"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

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

    init(id: UUID? = nil, title: String, createdAt: Date? = nil, updatedAt: Date? = nil, authorId: User.IDValue) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        $author.id = authorId
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
}
