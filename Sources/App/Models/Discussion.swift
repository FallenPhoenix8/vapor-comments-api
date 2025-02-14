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

// extension Discussion {
//     func toDictionary(request: Request) async throws -> [String: String] {
//         let dateFormatter = ISO8601DateFormatter()
//         let createdAtString = dateFormatter.string(from: createdAt ?? Date())
//         let updatedAtString = dateFormatter.string(from: updatedAt ?? Date())

//         let participants = try await Participant.query(on: request.db)
//             .filter(\.$discussion.$id == $id.value!)
//             .all()

//         let participantsString = try JSONSerialization.data(withJSONObject: participants).base64EncodedString()

//         return [
//             "id": id?.uuidString ?? "",
//             "title": title,
//             "createdAt": createdAtString,
//             "updatedAt": updatedAtString,
//             "participants": participantsString,
//         ]
//     }
// }
