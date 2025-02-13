import Fluent
import Vapor

final class Discussion: Model, Content, @unchecked Sendable {
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
    var user: User

    @Children(for: \.$discussion)
    var comments: [Comment]

    init() {}

    init(id: UUID? = nil, title: String, createdAt: Date? = nil, updatedAt: Date? = nil, userId: User.IDValue) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        $user.id = userId
    }
}

extension Discussion {
    func toDictionary() -> [String: String] {
        let dateFormatter = ISO8601DateFormatter()
        let createdAtString = dateFormatter.string(from: createdAt ?? Date())
        let updatedAtString = dateFormatter.string(from: updatedAt ?? Date())

        return [
            "id": id?.uuidString ?? "",
            "title": title,
            "createdAt": createdAtString,
            "updatedAt": updatedAtString,
        ]
    }
}
