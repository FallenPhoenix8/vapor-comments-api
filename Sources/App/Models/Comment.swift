import Foundation
import Vapor

public struct Comment: Decodable, Encodable, Sendable, Identifiable {
    public nonisolated(unsafe) static var comments: [Comment] = []
    private static let queue = DispatchQueue(label: "comments")

    public let id: Double
    public let content: String

    init(content: String) {
        id = Date().timeIntervalSince1970
        self.content = content
    }

    init(id: Double) throws {
        self.id = id
        var existingComment: Comment? = nil
        for comment in type(of: self).comments {
            if comment.id == id {
                existingComment = comment
            }
        }
        content = existingComment?.content ?? ""
        if existingComment == nil {
            throw Abort(.notFound)
        }
    }

    static func updateCommentGlobalStorage() -> [Comment] {
        if !fileManager.fileExists(atPath: "Sources/comments.json") {
            _ = fileManager.createFile(atPath: "Sources/comments.json", contents: "[]".data(using: String.Encoding.utf8))
        }
        var savedComments: [Comment] = []
        do {
            savedComments = try JSONDecoder().decode([Comment].self, from: Data(contentsOf: URL(fileURLWithPath: "Sources/comments.json")))
        } catch {
            _ = Abort(.badRequest, reason: "Error decoding comments.json: \(error)")
        }
        queue.sync {
            comments = savedComments
        }

        return comments
    }

    private static func writeComments(comments: [Comment]) async -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        var data = Data()
        do {
            data = try encoder.encode(comments)
        } catch {
            _ = Abort(.badRequest, reason: "Error encoding comments: \(error)")
        }

        do {
            try data.write(to: URL(fileURLWithPath: "Sources/comments.json"))
        } catch let err {
            _ = Abort(.internalServerError, reason: "Error writing comments.json: \(err)")
        }

        return data
    }

    func add() async throws -> [Comment] {
        var comments = type(of: self).updateCommentGlobalStorage()
        comments.append(self)

        _ = await type(of: self).writeComments(comments: comments)
        _ = Comment.updateCommentGlobalStorage()

        return comments
    }

    func delete() async throws -> [Comment] {
        let id = self.id
        var comments = type(of: self).updateCommentGlobalStorage()
        comments = comments.filter { $0.id != id }
        _ = await type(of: self).writeComments(comments: comments)
        _ = Comment.updateCommentGlobalStorage()
        return comments
    }
}
