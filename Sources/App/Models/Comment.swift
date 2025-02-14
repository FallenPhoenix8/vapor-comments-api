import Fluent
import Foundation
import Vapor

/// A model representing a comment with a unique identifier and content.
///
/// The `Comment` struct is used to encapsulate the details of a comment, including its content and a unique identifier.
/// Comments are stored in a global static array and can be added or removed. This struct also supports encoding and decoding
/// to facilitate easy storage and retrieval from a JSON file.
///
/// Fields:
/// - **`id`**: A unique `Double` identifier for the comment, generated based on the current time.
/// - **`content`**: The textual content of the comment.
///
/// Methods:
/// - **`init(content: String)`**: Initializes a new comment with the given content and a unique ID.
/// - **`init(id: Double) throws`**: Initializes a comment by its ID, throwing an error if not found.
/// - **`add() async throws -> [Comment]`**: Adds the comment to storage and returns the updated list of comments.
/// - **`delete() async throws -> [Comment]`**: Deletes the comment from storage and returns the updated list of comments.
/// - **`updateCommentGlobalStorage() -> [Comment]`**: Updates the global storage of comments from the JSON file.

// public struct Comment: Decodable, Encodable, Sendable, Identifiable {
//     /// The global storage of comments. This array is used to store and retrieve comments from storage.
//     private nonisolated(unsafe) static var comments: [Comment] = []
//     private static let queue = DispatchQueue(label: "comments")
//     private static let fileManager: FileManager = .init()

//     public let id: Double
//     public let content: String

//     init(content: String) {
//         id = Date().timeIntervalSince1970
//         self.content = content
//     }

//     /// Initializes a comment by its ID, throwing an error if not found.
//     ///
//     /// Use this initializer to fetch a comment from storage by its ID. If the comment is not found, an error will be thrown.
//     /// - Parameter id: The unique identifier of the comment to fetch.
//     /// - Throws: An error if the comment cannot be found.
//     init(id: Double) throws {
//         self.id = id
//         var existingComment: Comment? = nil
//         for comment in type(of: self).comments {
//             if comment.id == id {
//                 existingComment = comment
//             }
//         }

//         if existingComment == nil {
//             throw Abort(.notFound)
//         }
//         content = existingComment?.content ?? ""
//     }

//     /// Updates the global storage of comments from the JSON file.
//     ///
//     /// This method reads the saved comments from the "Sources/comments.json" file and updates the static `comments` array with the retrieved data.
//     /// If the file does not exist, it creates an empty JSON file to store comments.
//     ///
//     /// - Returns: An array of `Comment` objects representing the current global storage of comments.
//     /// - Aborts request: Aborts connection if there is an issue decoding the JSON file.

//     static func updateCommentGlobalStorage() -> [Comment] {
//         if !fileManager.fileExists(atPath: "Sources/comments.json") {
//             _ = fileManager.createFile(atPath: "Sources/comments.json", contents: "[]".data(using: String.Encoding.utf8))
//         }
//         var savedComments: [Comment] = []
//         do {
//             savedComments = try JSONDecoder().decode([Comment].self, from: Data(contentsOf: URL(fileURLWithPath: "Sources/comments.json")))
//         } catch {
//             _ = Abort(.badRequest, reason: "Error decoding comments.json: \(error)")
//         }
//         queue.sync {
//             comments = savedComments
//         }

//         return comments
//     }

//     /// Writes the given comments to the "Sources/comments.json" file.
//     ///
//     /// This method writes the given array of `Comment` objects to the JSON file, overwriting any existing file contents.
//     /// - Parameter comments: The array of `Comment` objects to write to storage.
//     /// - Returns: The JSON data representing the stored comments.
//     /// - Aborts request: Aborts connection if there is an issue encoding or writing the JSON file.

//     private static func writeComments(comments: [Comment]) -> Data {
//         let encoder = JSONEncoder()
//         encoder.outputFormatting = .prettyPrinted
//         var data = Data()
//         do {
//             data = try encoder.encode(comments)
//         } catch {
//             _ = Abort(.badRequest, reason: "Error encoding comments: \(error)")
//         }

//         do {
//             try data.write(to: URL(fileURLWithPath: "Sources/comments.json"))
//         } catch let err {
//             _ = Abort(.internalServerError, reason: "Error writing comments.json: \(err)")
//         }

//         return data
//     }

//     /// Adds the current comment to the global storage.
//     ///
//     /// This asynchronous method appends the current `Comment` instance to the global storage array of comments,
//     /// then updates the JSON file with the new list of comments.
//     ///
//     /// - Returns: An updated array of `Comment` objects representing the current global storage.
//     /// - Throws: An error if the process of adding the comment or updating the storage fails.

//     func add() async throws -> [Comment] {
//         var comments = type(of: self).updateCommentGlobalStorage()
//         comments.append(self)

//         _ = type(of: self).writeComments(comments: comments)
//         _ = Comment.updateCommentGlobalStorage()

//         return comments
//     }

//     /// Deletes the current comment from the global storage.
//     ///
//     /// This asynchronous method removes the `Comment` instance with the matching ID from the global storage array,
//     /// then updates the JSON file to reflect the removal.
//     ///
//     /// - Returns: An updated array of `Comment` objects representing the current global storage after the deletion.
//     /// - Throws: An error if the process of deleting the comment or updating the storage fails.

//     func delete() async throws -> [Comment] {
//         let id = self.id
//         var comments = type(of: self).updateCommentGlobalStorage()
//         comments = comments.filter { $0.id != id }
//         _ = type(of: self).writeComments(comments: comments)
//         _ = Comment.updateCommentGlobalStorage()
//         return comments
//     }
// }

final class Comment: Model, @unchecked Sendable, Content {
    static let schema = "comments"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "content")
    var content: String

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    @Parent(key: "discussionId") // This should match your database schema
    var discussion: Discussion

    @Parent(key: "participantId")
    var participant: Participant

    init() {}

    init(
        id: UUID? = nil,
        content: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        discussionId: Discussion.IDValue,
        participantId: Participant.IDValue
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        $discussion.id = discussionId
        $participant.id = participantId
    }
}

extension Comment {
    func toDictionary() -> [String: String] {
        let dateFormatter = ISO8601DateFormatter()
        let createdAtString = dateFormatter.string(from: createdAt!)
        let updatedAtString = dateFormatter.string(from: updatedAt!)
        return [
            "id": id?.uuidString ?? "",
            "content": content,
            "createdAt": createdAtString,
            "updatedAt": updatedAtString,
            "authorUsername": $participant.value?.$user.value?.username ?? "",
            "discussionId": $discussion.value?.id?.uuidString ?? "",
            "discussionTitle": $discussion.value?.title ?? "",
        ]
    }
}
